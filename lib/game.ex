defmodule Game do
  alias __MODULE__
  alias Game.CombatState
  alias Game.Combat

  @initial_state %{
    # Creates a 5x5x5 hex grid centered at (0,0,0)
    grid: Game.Grid.new({2, 2, 2}),
    characters: [
      %Game.Character{},
      %Game.Character{}
    ],
    combat: %Game.CombatState{}
  }

  @doc """
  This module implements a turn-based combat system via a GenServer.
  Each instance represents a separate game running concurrently.

  The rules of the game are defined in the `Game.Combat` module.
  """

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def subscribe(game_pid) do
    Phoenix.PubSub.subscribe(Game.PubSub, topic(game_pid))
  end

  defp topic(game_pid), do: "game:#{inspect(game_pid)}"

  defp broadcast(game_pid, state, animations \\ []) do
    Phoenix.PubSub.broadcast(Game.PubSub, topic(game_pid), {:game_updated, state, animations})
  end

  # Initialize combat with a random grid with two characters
  def init(_opts) do
    {:ok, @initial_state}
  end

  @doc """
  Initializes a new combat match with the given characters and grid.
  """
  def init_combat(game_pid, characters, grid) do
    GenServer.call(game_pid, {:init_combat, characters, grid})
  end

  @doc """
  Makes a character move to a new position.
  Returns {:ok, updated_state} or {:error, reason}
  """
  def move_character(game_pid, character, target_position) do
    GenServer.call(game_pid, {:move, character, target_position})
  end

  @doc """
  Plays a card from a character's hand.
  Returns {:ok, updated_state} or {:error, reason}
  """
  def play_card(game_pid, character, card, target_position) do
    GenServer.call(game_pid, {:play_card, character, card, target_position})
  end

  @doc """
  Gets the current state of the game.
  """
  def get_state(game_pid) do
    GenServer.call(game_pid, :get_state)
  end

  def process_action(game_pid, action, log_entry \\ nil) do
    GenServer.call(game_pid, {:process_action, action, log_entry})
  end

  @doc """
  Enters the shop state after combat is over.
  Returns {:ok, updated_state} or {:error, reason}
  """
  def enter_shop(game_pid) do
    GenServer.call(game_pid, :enter_shop)
  end

  def pick_booster_card(game_pid, player_id, card) do
    GenServer.call(game_pid, {:pick_booster_card, player_id, card})
  end

  def generate_booster_cards(count) do
    Game.BaseCards.list_basecards()
    |> Enum.shuffle()
    |> Enum.take(count)
    |> Enum.with_index(1000)
    |> Enum.map(fn {base_card, id} -> base_card_to_game_card(base_card, id) end)
  end

  # Callbacks

  def handle_call({:init_combat, characters, grid}, _from, _state) do
    # Initialize a 6x6 grid if none provided
    grid = if grid == %Game.Grid{}, do: Game.Grid.new({3, 3, 3}), else: grid

    grid =
      Map.update(grid, :tiles, %{}, fn tiles ->
        Enum.reduce(tiles, %{}, fn {key, value}, acc ->
          character = Enum.find(characters, &(&1.position == key))

          Map.put(acc, key, %{
            value
            | occupied_by:
                if character do
                  character
                else
                  nil
                end
          })
        end)
      end)

    combat = %CombatState{
      state: :running,
      __constants__: %{
        players: characters
      },
      queue: characters,
      grid: grid,
      current_turn: %{
        starting_position: hd(characters).position,
        player: hd(characters),
        card: nil
      }
    }

    new_state = %{
      grid: grid,
      characters: characters,
      combat: combat
    }

    {:reply, {:ok, combat}, new_state}
  end

  def handle_call({:move, character, target_position}, _from, state) do
    # Get the latest version of the character from state
    current_character = Enum.find(state.combat.queue, &(&1.id == character.id))

    case Combat.process_action(state.combat, {:move, current_character, target_position}) do
      {:ok, updated_combat} ->
        {:reply, {:ok, updated_combat}, %{state | combat: updated_combat}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:play_card, character, card, target_position}, _from, state) do
    # Get the latest version of the character from state
    current_character = Enum.find(state.combat.queue, &(&1.id == character.id))

    # Check if it's the character's turn
    [current_turn | _] = state.combat.queue

    if current_turn.id != current_character.id do
      {:reply, {:error, "Not player's turn"}, state}
    else
      # First pick the card
      case Combat.process_action(state.combat, {:pick_card, current_character, card}) do
        {:ok, card_selected_combat} ->
          # Then play the card
          case Combat.process_action(card_selected_combat, {:play_card, target_position}) do
            {:ok, updated_combat, _animations} ->
              _current_character =
                Enum.find(updated_combat.queue, &(&1.id == current_character.id))

              updated_state = %{state | combat: updated_combat}
              {:reply, {:ok, updated_combat}, updated_state}

            {:error, reason} ->
              {:reply, {:error, reason}, state}
          end

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    end
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:set_state, new_state}, _from, _state) do
    {:reply, :ok, new_state}
  end

  def handle_call({:process_action, action, log_entry}, _from, state) do
    case Combat.process_action(state.combat, action) do
      {:ok, updated_combat} ->
        {:ok, final_combat} = Game.AI.advance_through_ai_turns(updated_combat)
        new_state = append_log(%{state | combat: final_combat}, log_entry)
        broadcast(self(), new_state)
        {:reply, {:ok, new_state}, new_state}

      {:ok, updated_combat, animations} ->
        {:ok, final_combat} = Game.AI.advance_through_ai_turns(updated_combat)
        new_state = append_log(%{state | combat: final_combat}, log_entry)
        target_id = resolve_animation_target(state.combat, action)
        tagged_animations = Enum.map(animations, &Map.put(&1, :target_id, target_id))
        broadcast(self(), new_state, tagged_animations)
        {:reply, {:ok, new_state, tagged_animations}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:pick_booster_card, player_id, card}, _from, state) do
    # Only update __constants__.players — the authoritative pre-combat character state.
    # queue and current_turn are derived from it when combat is (re)initialized.
    updated_constants_players =
      Enum.map(state.combat.__constants__.players, fn p ->
        if to_string(p.id) == to_string(player_id) do
          new_id = length(p.cards.draw) + length(p.cards.hand) + length(p.cards.discard)
          %{p | cards: %{p.cards | draw: p.cards.draw ++ [%{card | id: new_id}]}}
        else
          p
        end
      end)

    updated_combat = %{
      state.combat
      | __constants__: %{state.combat.__constants__ | players: updated_constants_players}
    }

    # Update this player's per-player booster countdown.
    booster_size = get_in(state, [:settings, :booster_size]) || 5
    deck_picks = get_in(state, [:settings, :deck_picks]) || 1

    player_booster =
      Map.get(state.booster_state, player_id, %{
        remaining: 1,
        picks_remaining: deck_picks,
        cards: []
      })

    picks_remaining = (player_booster[:picks_remaining] || deck_picks) - 1

    remaining_cards = List.delete(player_booster.cards, card)

    next_player_booster =
      if picks_remaining > 0 do
        # Still picks left in this pack — remove picked card, keep pack open
        %{player_booster | picks_remaining: picks_remaining, cards: remaining_cards}
      else
        # Pack exhausted — open next pack or close out
        remaining = player_booster.remaining - 1

        if remaining > 0 do
          %{
            remaining: remaining,
            picks_remaining: deck_picks,
            cards: generate_booster_cards(booster_size)
          }
        else
          %{remaining: 0, picks_remaining: 0, cards: []}
        end
      end

    new_booster_state = Map.put(state.booster_state, player_id, next_player_booster)

    # When all players are done, rebuild combat from the updated __constants__.players
    # so queue, current_turn, and grid are all derived cleanly from the final decks.
    all_done = Enum.all?(new_booster_state, fn {_, b} -> b.remaining == 0 end)

    {next_view, final_combat} =
      if all_done do
        specs =
          Enum.map(updated_constants_players, fn p ->
            %{character: p, team: p.team, position: p.position, id: p.id}
          end)

        {:combat, Game.CombatBuilder.build(specs, settings: state[:settings])}
      else
        {:booster, updated_combat}
      end

    new_state = %{
      state
      | combat: final_combat,
        booster_state: new_booster_state,
        current_view: next_view
    }

    broadcast(self(), new_state)
    {:reply, {:ok, new_state}, new_state}
  end

  def handle_call(:enter_shop, _from, state) do
    if state.combat.state == :game_over do
      # Generate 4 shop cards
      shop_cards = generate_shop_cards(4)

      # Update combat state to shop mode
      updated_combat = %{state.combat | state: :shop, shop_cards: shop_cards}
      updated_state = %{state | combat: updated_combat}

      {:reply, {:ok, updated_state}, updated_state}
    else
      {:reply, {:error, "Can only enter shop after combat is over"}, state}
    end
  end

  defp append_log(state, nil), do: state

  defp append_log(state, entry) do
    log = Map.get(state, :action_log, [])
    Map.put(state, :action_log, Enum.slice([entry | log], 0, 20))
  end

  defp resolve_animation_target(_combat, {:play_card_on_character, character}),
    do: to_string(character.id)

  defp resolve_animation_target(combat, {:play_card, position}) do
    case Game.Grid.get_object(combat.grid, position) do
      {:ok, %{id: id}} -> to_string(id)
      _ -> nil
    end
  end

  defp generate_shop_cards(count) do
    Game.BaseCards.list_basecards()
    |> Enum.shuffle()
    |> Enum.take(count)
    |> Enum.with_index(1000)
    |> Enum.map(fn {base_card, id} -> base_card_to_game_card(base_card, id) end)
  end

  defp base_card_to_game_card(base_card, id) do
    base_card
    |> Map.drop([:__meta__, :__struct__, :inserted_at, :updated_at, :ap, :slug])
    |> Map.merge(%{cost: base_card.ap, id: id})
    |> then(&struct!(Game.Card, &1))
  end
end
