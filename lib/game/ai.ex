defmodule Game.AI do
  @moduledoc """
  Runs a full AI turn for the current player using a FF12-style gambit list.

  A gambit is a map with:
    - "trigger"     — JsonLogic expression evaluated against {caster, queue, state}
    - "action"      — "damage" | "heal" | "shield" | "move_closer" | "move_away" | "skip_turn"
    - "card_filter" — effect type to search for in hand (optional, used for card actions)

  The loop iterates tactics top-to-bottom each pass, fires the first matching one, then
  restarts from the top. Stops when skip_turn fires, no gambit matches, or the circuit
  breaker (@max_actions) trips.
  """

  require Logger
  alias Game.{CombatState, Combat, Card, Grid, Formula}

  @max_actions 10

  @spec run_turn(CombatState.t(), list(map())) :: {:ok, CombatState.t()}
  def run_turn(combat, tactics), do: do_run(combat, tactics, @max_actions)

  @doc """
  After any action that may advance the turn, call this to automatically run
  through any consecutive AI-controlled turns until a human player is current.
  Safe to call regardless of whether the next player is AI-controlled.
  """
  @spec advance_through_ai_turns(CombatState.t()) :: {:ok, CombatState.t()}
  def advance_through_ai_turns(combat) do
    player = CombatState.get_current_player(combat)

    if Game.Character.is_ai_controlled?(player) do
      {:ok, updated} = run_turn(combat, player.tactics)
      advance_through_ai_turns(updated)
    else
      {:ok, combat}
    end
  end

  defp do_run(combat, _tactics, 0) do
    Logger.warning(
      "AI circuit-breaker tripped for #{inspect(CombatState.get_current_player(combat).name)}"
    )

    {:ok, combat}
  end

  defp do_run(combat, tactics, remaining) do
    caster = CombatState.get_current_player(combat)
    context = build_context(caster, combat)

    case find_matching_gambit(tactics, context) do
      nil ->
        {:ok, combat}

      %{"action" => "skip_turn"} ->
        {:ok, elem(Combat.process_action(combat, {:skip_turn, caster}), 1)}

      gambit ->
        case execute(gambit, caster, combat) do
          {:ok, updated_combat} ->
            do_run(updated_combat, tactics, remaining - 1)

          {:error, reason} ->
            Logger.debug("AI gambit failed (#{reason}), trying next")
            # Skip the failed gambit and try the rest of the list
            remaining_tactics = tactics -- [gambit]
            do_run(combat, remaining_tactics, remaining - 1)
        end
    end
  end

  defp find_matching_gambit(tactics, context) do
    Enum.find(tactics, fn %{"trigger" => trigger} ->
      Formula.resolve(trigger, context)
    end)
  end

  defp execute(%{"action" => "move_closer"}, caster, combat) do
    case best_move(caster, combat, :closer) do
      nil ->
        {:error, "no reachable tile closer to enemy"}

      pos ->
        elem(Combat.process_action(combat, {:move, caster, pos}), 0)
        |> case do
          :ok -> Combat.process_action(combat, {:move, caster, pos})
          _ -> {:error, "move rejected"}
        end
    end
  end

  defp execute(%{"action" => "move_away"}, caster, combat) do
    case best_move(caster, combat, :away) do
      nil ->
        {:error, "no reachable tile further from enemy"}

      pos ->
        Combat.process_action(combat, {:move, caster, pos})
        |> case do
          {:ok, updated} -> {:ok, updated}
          _ -> {:error, "move rejected"}
        end
    end
  end

  defp execute(%{"action" => action, "card_filter" => filter} = _gambit, caster, combat)
       when is_binary(action) do
    filter = filter || action

    with {:ok, card} <- pick_card(caster, filter),
         {:ok, target_pos} <- find_target(card, caster, combat),
         {:ok, combat_after_pick} <- Combat.process_action(combat, {:pick_card, caster, card}),
         {:ok, result, _anims} <-
           Combat.process_action(combat_after_pick, {:play_card, target_pos}) do
      {:ok, result}
    end
  end

  defp execute(%{"action" => action} = gambit, caster, combat) do
    execute(Map.put(gambit, "card_filter", action), caster, combat)
  end

  # --- helpers ---

  defp pick_card(caster, effect_type) do
    card =
      caster.cards.hand
      |> Enum.find(fn card ->
        Enum.any?(card.effects, fn effect ->
          Map.get(effect, :type) == String.to_atom(effect_type) or
            Map.get(effect, "type") == effect_type
        end)
      end)

    if card, do: {:ok, card}, else: {:error, "no #{effect_type} card in hand"}
  end

  defp find_target(card, caster, combat) do
    enemies = enemies_of(caster, combat)

    target_pos =
      Enum.find_value(enemies, fn enemy ->
        case Card.is_target_valid_for_character?(card, enemy, combat) do
          {:ok, _} -> enemy.position
          _ -> nil
        end
      end)

    if target_pos, do: {:ok, target_pos}, else: {:error, "no valid target in range"}
  end

  defp best_move(caster, combat, direction) do
    enemies = enemies_of(caster, combat)
    if enemies == [], do: nil, else: do_best_move(caster, combat, enemies, direction)
  end

  defp do_best_move(caster, combat, enemies, direction) do
    reachable =
      Grid.tiles_in_range(combat.grid, caster.position, caster.movement_range)
      |> Enum.reject(&Grid.tile_blocked?(combat.grid, &1))
      |> Enum.reject(&(&1 == caster.position))

    nearest_enemy =
      Enum.min_by(enemies, &Grid.distance(combat.grid, caster.position, &1.position))

    case direction do
      :closer ->
        Enum.min_by(reachable, &Grid.distance(combat.grid, &1, nearest_enemy.position), fn ->
          nil
        end)

      :away ->
        Enum.max_by(reachable, &Grid.distance(combat.grid, &1, nearest_enemy.position), fn ->
          nil
        end)
    end
  end

  defp enemies_of(caster, combat) do
    CombatState.get_current_queue(combat)
    |> Enum.reject(&(&1.team == caster.team or &1.dead))
  end

  defp build_context(caster, combat) do
    all_chars = [caster | CombatState.get_current_queue(combat)]

    {:ok, caster_json} = caster |> strip_cards() |> Jason.encode()
    {:ok, caster_map} = Jason.decode(caster_json)
    {:ok, queue_json} = all_chars |> Enum.map(&strip_cards/1) |> Jason.encode()
    {:ok, queue_list} = Jason.decode(queue_json)

    # Encode the combat state without the card-heavy queue to avoid struct issues
    state_map = %{
      "current_turn" => %{
        "player" => caster_map,
        "starting_position" => Tuple.to_list(combat.current_turn.starting_position)
      }
    }

    %{"caster" => caster_map, "queue" => queue_list, "state" => state_map}
  end

  defp strip_cards(character) do
    %{character | cards: %{draw: [], hand: [], discard: []}}
  end
end
