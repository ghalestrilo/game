defmodule GameWeb.GameLive do
  use GameWeb, :live_view
  import GameWeb.CombatActionHelpers
  alias Game
  alias Game.CombatState.StateSave

  @impl true
  def mount(_params, session, socket) do
    session_id = session["_csrf_token"]

    if connected?(socket) do
      game_state = %{
        current_view: :combat,
        grid: nil,
        characters: [],
        combat: %Game.CombatState{
          state: :running,
          __constants__: %{
            players: []
          },
          queue: [],
          grid: nil,
          current_turn: %{
            starting_position: nil,
            player: nil,
            card: nil
          }
        }
      }

      {:ok,
       assign(socket,
         game_pid: nil,
         game_state: game_state,
         initial_game_state: game_state,
         action_log: [],
         modal: nil,
         session_id: session_id
       )}
    else
      {:ok, assign(socket, game_state: nil, action_log: [], modal: nil, session_id: session_id)}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    if params["initial_state"] do
      case decode_initial_state(params["initial_state"]) do
        {:ok, initial_state} ->
          {:ok, game_pid} = Game.start_link()

          combat_state = Game.Combat.initialize_from_char_params_list(initial_state)

          game_state = %{
            current_view: :combat,
            grid: combat_state.grid,
            characters: combat_state.__constants__.players,
            combat: combat_state
          }

          :ok = GenServer.call(game_pid, {:set_state, game_state})

          {:noreply,
           assign(socket,
             game_pid: game_pid,
             game_state: game_state,
             initial_game_state: game_state
           )}

        {:error, reason} ->
          {:noreply,
           socket
           |> put_flash(:error, "Failed to load initial state: #{reason}")
           |> assign(game_pid: nil, game_state: nil)}
      end
    else
      case Game.CombatSaves.load(socket.assigns.session_id) do
        {:ok, combat_state} ->
          {:ok, game_pid} = Game.start_link()

          game_state = %{
            current_view: :combat,
            grid: combat_state.grid,
            characters: combat_state.__constants__.players,
            combat: combat_state
          }

          :ok = GenServer.call(game_pid, {:set_state, game_state})

          {:noreply,
           assign(socket,
             game_pid: game_pid,
             game_state: game_state,
             initial_game_state: game_state
           )}

        {:error, _} ->
          {:noreply, socket}
      end
    end
  end

  defp decode_initial_state(encoded_state) do
    encoded_state
    |> String.trim_leading("[")
    |> String.trim_trailing("]")
    |> String.split(",")
    |> Enum.map(fn entry ->
      case String.split(entry, ":") do
        [position, class, team] ->
          {parse_position(position), String.to_atom(class), String.to_integer(team)}

        _ ->
          raise "Invalid format for initial_state entry: #{entry}"
      end
    end)
    |> then(&{:ok, &1})
  rescue
    _ -> {:error, "Invalid initial_state format"}
  end

  defp parse_position(position) do
    position
    |> String.split("_")
    |> Enum.map(&String.to_integer/1)
    |> List.to_tuple()
  end

  def find_character(characters, position) do
    Enum.find(characters, fn char -> char.position == position end)
  end

  def character_class(%{class: class}),
    do: "character !bg-cover !bg-no-repeat #{get_class_bg(to_string(class))}"

  defp get_class_bg("bard"), do: "!bg-[url('/images/cat-bard.png')]"
  defp get_class_bg("cleric"), do: "!bg-[url('/images/cat-cleric.png')]"
  defp get_class_bg("druid"), do: "!bg-[url('/images/cat-druid.png')]"
  defp get_class_bg("fighter"), do: "!bg-[url('/images/cat-fighter.png')]"
  defp get_class_bg("mage"), do: "!bg-[url('/images/cat-mage.png')]"
  defp get_class_bg("monk"), do: "!bg-[url('/images/cat-monk.png')]"
  defp get_class_bg("paladin"), do: "!bg-[url('/images/cat-paladin.png')]"
  defp get_class_bg("ranger"), do: "!bg-[url('/images/cat-ranger.png')]"
  defp get_class_bg("sorcerer"), do: "!bg-[url('/images/cat-sorcerer.png')]"
  defp get_class_bg("rogue"), do: "!bg-[url('/images/cat-rogue.png')]"
  defp get_class_bg("warlock"), do: "!bg-[url('/images/cat-warlock.png')]"
  defp get_class_bg(_), do: "!bg-none"

  @impl true
  def handle_event("reset", _params, socket) do
    {:noreply,
     assign(socket,
       game_state: socket.assigns.initial_game_state,
       action_log: []
     )}
  end

  def handle_event("pick_card", params, socket) do
    current_turn = socket.assigns.game_state.combat.current_turn
    card = current_turn.player.cards.hand |> Enum.at(String.to_integer(params["card_index"]))

    combat =
      with {:ok, updated_combat} <-
             apply_combat_action(socket.assigns.game_state.combat, {:pick_card, current_turn.player, card}) do
        updated_combat
      else
        {:error, _error} ->
          socket.assigns.game_state.combat
      end

    action = "#{current_turn.player.name} selected card: #{card.name}"
    updated_log = [action | socket.assigns.action_log]

    checkpoint_combat(socket.assigns.session_id, combat)

    {:noreply,
     assign(socket,
       game_state: %{socket.assigns.game_state | combat: combat},
       action_log: updated_log
     )}
  end

  def handle_event(
        "interact",
        %{"target_character_id" => character_id},
        %{
          assigns: %{game_state: %{combat: %{state: :card_selected, current_turn: %{card: card}}}}
        } = socket
      ) do
    combat = socket.assigns.game_state.combat

    character =
      Game.CombatState.get_current_queue(combat)
      |> Enum.find(fn c -> c && to_string(c.id) == character_id end)

    with true <- not is_nil(character),
         {:ok, updated_combat, animations} <-
           Game.Combat.process_action(combat, {:play_card_on_character, character}) do
      action = "#{combat.current_turn.player.name} played card: #{card.name}"
      updated_log = [action | socket.assigns.action_log]

      hit_color =
        animations
        |> List.first()
        |> then(fn
          %{color: color} -> color
          _ -> :yellow
        end)

      socket =
        assign(socket,
          game_state: %{socket.assigns.game_state | combat: updated_combat},
          action_log: updated_log
        )
        |> push_event("hit", %{id: character_id, color: hit_color})
        |> then(fn s ->
          Enum.reduce(animations, s, fn anim, s ->
            push_event(s, "float", %{id: character_id, label: anim.label, color: anim.color})
          end)
        end)

      checkpoint_combat(socket.assigns.session_id, updated_combat)

      {:noreply, socket}
    else
      false ->
        {:noreply, put_flash(socket, :error, "Character not found")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, "#{error}")}
    end
  end

  def handle_event(
        "interact",
        params,
        %{
          assigns: %{game_state: %{combat: %{state: :card_selected, current_turn: %{card: card}}}}
        } = socket
      ) do
    with {:ok, position} <- parse_hex_position(params["target_position"]),
         {:ok, combat, animations} <-
           Game.Combat.process_action(socket.assigns.game_state.combat, {:play_card, position}) do
      action =
        "#{socket.assigns.game_state.combat.current_turn.player.name} played card: #{card.name}"

      updated_log = [action | socket.assigns.action_log]

      socket =
        assign(socket,
          game_state: %{socket.assigns.game_state | combat: combat},
          action_log: updated_log
        )

      socket =
        case Game.Grid.get_object(socket.assigns.game_state.combat.grid, position) do
          {:ok, %{id: id}} ->
            target_id = to_string(id)

            hit_color = animations |> List.first() |> then(fn
              %{color: color} -> color
              _ -> :yellow
            end)

            socket
            |> push_event("hit", %{id: target_id, color: hit_color})
            |> then(fn s ->
              Enum.reduce(animations, s, fn anim, s ->
                push_event(s, "float", %{id: target_id, label: anim.label, color: anim.color})
              end)
            end)

          _ ->
            socket
        end

      checkpoint_combat(socket.assigns.session_id, combat)

      {:noreply, socket}
    else
      {:error, error} ->
        {:noreply, put_flash(socket, :error, "#{error}")}
    end
  end

  def handle_event(
        "interact",
        %{"target_position" => target_position},
        %{
          assigns: %{game_state: %{combat: %{state: :running, current_turn: %{player: player}}}}
        } = socket
      ) do
    {:ok, position} = parse_hex_position(target_position)

    with {:ok, combat} <- apply_combat_action(socket.assigns.game_state.combat, {:move, player, position}) do
      action = "#{player.name} moved to position #{inspect(position)}"
      updated_log = [action | socket.assigns.action_log]

      checkpoint_combat(socket.assigns.session_id, combat)

      {:noreply,
       assign(socket,
         game_state: %{socket.assigns.game_state | combat: combat},
         action_log: updated_log
       )}
    else
      {:error, error} ->
        {:noreply, put_flash(socket, :error, "#{error}")}
    end
  end

  def handle_event("interact", _params, socket) do
    {:noreply, socket}
  end

  def handle_event(
        "skip_turn",
        _params,
        %{
          assigns: %{game_state: %{combat: %{current_turn: %{player: player}}}}
        } = socket
      ) do
    with {:ok, combat} <- apply_combat_action(socket.assigns.game_state.combat, {:skip_turn, player}) do
      action = "#{player.name} skipped their turn"
      updated_log = [action | socket.assigns.action_log]

      checkpoint_combat(socket.assigns.session_id, combat)

      {:noreply,
       assign(socket,
         game_state: %{socket.assigns.game_state | combat: combat},
         action_log: updated_log
       )}
    else
      {:error, error} ->
        {:noreply, put_flash(socket, :error, "#{error}")}
    end
  end

  def handle_event("win_match", _params, socket) do
    current_player = socket.assigns.game_state.combat.current_turn.player

    if is_nil(current_player) do
      {:noreply, put_flash(socket, :error, "No active player")}
    else
      updated_combat = force_game_over(socket.assigns.game_state.combat, current_player.team)
      updated_game_state = %{socket.assigns.game_state | combat: updated_combat}

      checkpoint_combat(socket.assigns.session_id, updated_combat)

      if socket.assigns.game_pid do
        :ok = GenServer.call(socket.assigns.game_pid, {:set_state, updated_game_state})
      end

      action = "#{current_player.name}'s team (#{current_player.team}) wins the match!"
      updated_log = [action | socket.assigns.action_log]

      {:noreply,
       assign(socket,
         game_state: updated_game_state,
         action_log: updated_log
       )}
    end
  end

  def handle_event("enter_shop", _params, socket) do
    if socket.assigns.game_state.combat.state == :game_over && socket.assigns.game_pid do
      case Game.enter_shop(socket.assigns.game_pid) do
        {:ok, updated_state} ->
          {:ok, updated_state}

          updated_state = Map.put(updated_state, :current_view, :shop)

          {:noreply,
           socket
           |> assign(game_state: updated_state, modal: nil)
           |> put_flash(:info, "Welcome to the shop!")}

        {:error, reason} ->
          {:error, reason}

          {:noreply,
           socket
           |> put_flash(:error, "Failed to enter shop: #{reason}")
           |> assign(modal: nil)}
      end
    else
      {:noreply, put_flash(socket, :error, "Combat must be over to enter shop")}
    end
  end

  def handle_event("load_game_state", %{"game_state" => encoded_state}, socket) do
    case StateSave.decode(encoded_state) do
      {:ok, combat} ->
        grid = combat.grid
        characters = combat.queue

        game_state = %{
          current_view: :combat,
          grid: grid,
          characters: characters,
          combat: combat
        }

        :ok = GenServer.call(socket.assigns.game_pid, {:set_state, game_state})

        {:noreply,
         socket
         |> assign(game_state: game_state, modal: nil)
         |> put_flash(:info, "Game state loaded successfully!")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to load game state: #{reason}")
         |> assign(modal: :load_game)}
    end
  end

  def handle_event("select_shop_card", %{"card_index" => _card_index}, socket) do
    updated_game_state = Map.put(socket.assigns.game_state, :current_view, :combat)

    {:noreply,
     socket
     |> assign(game_state: updated_game_state)
     |> put_flash(:info, "Card selected! Returning to combat...")}
  end

  @impl true
  def handle_info({:parent_event, event_name, params}, socket) do
    handle_event(event_name, params, socket)
  end
end
