defmodule GameWeb.GameLive do
  use GameWeb, :live_view
  alias Game
  alias Game.CombatState.StateSave

  @impl true
  def mount(_params, _session, socket) do
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
         modal: nil
       )}
    else
      {:ok, assign(socket, game_state: nil, action_log: [], modal: nil)}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    if params["initial_state"] do
      case decode_initial_state(params["initial_state"]) do
        {:ok, initial_state} ->
          # Create the game state
          {:ok, game_pid} = Game.start_link()

          combat_state = Game.Combat.initialize_from_char_params_list(initial_state)

          game_state = %{
            current_view: :combat,
            grid: combat_state.grid,
            characters: combat_state.__constants__.players,
            combat: combat_state
          }

          # Set the game state in the GenServer
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
      {:noreply, socket}
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
    # {game_pid, game_state} = initialize_game()
    {:noreply,
     assign(socket,
       # game_pid: game_pid,
       game_state: socket.assigns.initial_game_state,
       action_log: []
     )}
  end

  def handle_event("pick_card", params, socket) do
    current_turn = socket.assigns.game_state.combat.current_turn
    card = current_turn.player.cards.hand |> Enum.at(String.to_integer(params["card_index"]))

    combat =
      with {:ok, updated_combat} <-
             process_game_action(socket, {:pick_card, current_turn.player, card}) do
        updated_combat
      else
        {:error, _error} ->
          socket.assigns.game_state.combat
      end

    action = "#{current_turn.player.name} selected card: #{card.name}"
    updated_log = [action | socket.assigns.action_log]

    {:noreply,
     assign(socket,
       game_state: %{socket.assigns.game_state | combat: combat},
       action_log: updated_log
     )}
  end

  def handle_event(
        "interact",
        params,
        %{
          assigns: %{game_state: %{combat: %{state: :card_selected, current_turn: %{card: card}}}}
        } = socket
      ) do
    with {:ok, position} <- parse_target_position(params["target_position"]),
         {:ok, combat} <- process_game_action(socket, {:play_card, position}) do
      action =
        "#{socket.assigns.game_state.combat.current_turn.player.name} played card: #{card.name}"

      updated_log = [action | socket.assigns.action_log]

      {:noreply,
       assign(socket,
         game_state: %{socket.assigns.game_state | combat: combat},
         action_log: updated_log
       )}
    else
      {:error, error} ->
        socket =
          socket
          |> put_flash(:error, "#{error}")

        {:noreply, socket}
    end
  end

  def handle_event(
        "interact",
        %{"target_position" => target_position},
        %{
          assigns: %{game_state: %{combat: %{state: :running, current_turn: %{player: player}}}}
        } = socket
      ) do
    {:ok, position} = parse_target_position(target_position)

    with {:ok, combat} <- process_game_action(socket, {:move, player, position}) do
      action = "#{player.name} moved to position #{inspect(position)}"
      updated_log = [action | socket.assigns.action_log]

      {:noreply,
       assign(socket,
         game_state: %{socket.assigns.game_state | combat: combat},
         action_log: updated_log
       )}
    else
      {:error, error} ->
        socket =
          socket
          |> put_flash(:error, "#{error}")

        {:noreply, socket}
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
    with {:ok, combat} <- process_game_action(socket, {:skip_turn, player}) do
      action = "#{player.name} skipped their turn"
      updated_log = [action | socket.assigns.action_log]

      {:noreply,
       assign(socket,
         game_state: %{socket.assigns.game_state | combat: combat},
         action_log: updated_log
       )}
    else
      {:error, error} ->
        socket =
          socket
          |> put_flash(:error, "#{error}")

        {:noreply, socket}
    end
  end

  def handle_event("win_match", _params, socket) do
    if socket.assigns.game_state.combat.current_turn.player do
      current_player = socket.assigns.game_state.combat.current_turn.player
      winning_team = current_player.team

      # Mark all characters from other teams as dead
      updated_queue =
        Enum.map(socket.assigns.game_state.combat.queue, fn char ->
          if char.team != winning_team do
            %{char | dead: true, hp: 0}
          else
            char
          end
        end)

      # Update current player if they're not on the winning team
      updated_current_player =
        if current_player.team != winning_team do
          %{current_player | dead: true, hp: 0}
        else
          current_player
        end

      # Set combat state to game_over
      updated_combat = %{
        socket.assigns.game_state.combat
        | state: :game_over,
          queue: updated_queue,
          current_turn: %{
            socket.assigns.game_state.combat.current_turn
            | player: updated_current_player
          }
      }

      updated_game_state = %{socket.assigns.game_state | combat: updated_combat}

      # Sync the updated state to the GenServer
      if socket.assigns.game_pid do
        :ok = GenServer.call(socket.assigns.game_pid, {:set_state, updated_game_state})
      end

      action = "#{current_player.name}'s team (#{winning_team}) wins the match!"
      updated_log = [action | socket.assigns.action_log]

      {:noreply,
       assign(socket,
         game_state: updated_game_state,
         action_log: updated_log
       )}
    else
      {:noreply, put_flash(socket, :error, "No active player")}
    end
  end

  def handle_event("enter_shop", _params, socket) do
    if dbg(socket.assigns.game_state.combat.state) == :game_over && dbg(socket.assigns.game_pid) do
      # Transition to shop
      case Game.enter_shop(socket.assigns.game_pid) do
        {:ok, updated_state} ->
          dbg({:ok, updated_state})

          # Add current_view: :shop to the updated state
          updated_state = Map.put(updated_state, :current_view, :shop)

          {:noreply,
           socket
           |> assign(game_state: updated_state, modal: nil)
           |> put_flash(:info, "Welcome to the shop!")}

        {:error, reason} ->
          dbg({:error, reason})

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

        # Create the game state with our combat struct
        game_state = %{
          current_view: :combat,
          grid: grid,
          characters: characters,
          combat: combat
        }

        # Set the game state in the GenServer
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
    # For now, just return to combat view
    # TODO: Add the selected card to a player's deck
    updated_game_state = Map.put(socket.assigns.game_state, :current_view, :combat)

    {:noreply,
     socket
     |> assign(game_state: updated_game_state)
     |> put_flash(:info, "Card selected! Returning to combat...")}
  end

  defp process_game_action(socket, action) do
    with {:ok, updated_combat} <-
           Game.Combat.process_action(
             socket.assigns.game_state.combat,
             action
           ) do
      {:ok, updated_combat}
    else
      {:error, error} ->
        {:error, error}
    end
  end

  defp parse_target_position(target_position) do
    with [q, r, s] <-
           target_position
           |> String.split("_")
           |> Enum.map(&String.to_integer/1) do
      {:ok, {q, r, s}}
    else
      _ -> {:error, "Invalid target position"}
    end
  end

  @impl true
  def handle_info({:parent_event, event_name, params}, socket) do
    handle_event(event_name, params, socket)
  end
end
