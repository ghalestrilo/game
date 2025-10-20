defmodule GameWeb.GameLive do
  alias Game.Grid
  use GameWeb, :live_view
  alias Game
  alias Game.CombatState.StateSave
  alias Game.Fixtures

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      {game_pid, game_state} = initialize_game()

      {:ok,
       assign(socket, game_pid: game_pid, game_state: game_state, action_log: [], modal: nil)}
    else
      {:ok, assign(socket, game_pid: nil, game_state: nil, action_log: [], modal: nil)}
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
            grid: combat_state.grid,
            characters: combat_state.__constants__.players,
            combat: combat_state
          }

          # Set the game state in the GenServer
          :ok = GenServer.call(game_pid, {:set_state, game_state})

          {:noreply, assign(socket, game_pid: game_pid, game_state: game_state)}

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

  @impl true
  def handle_event("reset", _params, socket) do
    {game_pid, game_state} = initialize_game()
    {:noreply, assign(socket, game_pid: game_pid, game_state: game_state, action_log: [])}
  end

  defp find_character(characters, position) do
    Enum.find(characters, fn char -> char.position == position end)
  end

  # defp character_class(%{class: :mage}), do: "character mage"
  # defp character_class(%{class: :fighter}), do: "character warrior"
  defp character_class(%{class: class}),
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

  defp initialize_game() do
    {:ok, game_pid} = Game.start_link()
    # Get characters from fixtures with their decks
    warrior = Fixtures.warrior()
    mage = Fixtures.mage()

    # Set positions that work well in a hex grid
    warrior = %{warrior | position: {0, 0, 0}}
    mage = %{mage | position: {2, -1, -1}}

    # Draw initial cards for warrior only (first player)
    # The mage will draw cards when their turn starts
    warrior_with_cards = Game.Character.draw_cards(warrior, 5)
    # No cards initially for second player
    mage_with_cards = mage

    updated_players = [warrior_with_cards, mage_with_cards]

    # Create a proper hex grid with radius 2 (creates a balanced grid)
    grid = Game.Grid.new({2, 2, 2})

    # Update the grid with our characters
    grid = Game.Grid.update_character(grid, warrior_with_cards)
    grid = Game.Grid.update_character(grid, mage_with_cards)

    # Create combat struct with proper state
    combat = %Game.CombatState{
      state: :running,
      __constants__: %{
        players: updated_players
      },
      queue: updated_players,
      grid: grid,
      current_turn: %{
        starting_position: warrior_with_cards.position,
        player: warrior_with_cards,
        card: nil
      }
    }

    # Create the initial game state with our combat struct
    game_state = %{
      grid: grid,
      characters: updated_players,
      combat: combat
    }

    # Set the game state in the GenServer
    :ok = GenServer.call(game_pid, {:set_state, game_state})
    {game_pid, game_state}
  end

  def handle_event("pick_card", params, socket) do
    current_turn = socket.assigns.game_state.combat.current_turn
    card = current_turn.player.cards.hand |> Enum.at(String.to_integer(params["card_index"]))

    combat =
      with {:ok, updated_combat} <-
             process_game_action(socket, {:pick_card, current_turn.player, card}) do
        updated_combat
      else
        {:error, error} ->
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
      # Get next player for debugging
      [next_player | _] = combat.queue

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

  def handle_event("interact", params, socket) do
    {:noreply, socket}
  end

  def handle_event(
        "skip_turn",
        _params,
        %{
          assigns: %{game_state: %{combat: %{current_turn: %{player: player}}}}
        } = socket
      ) do
    # Print current player's card counts for debugging

    with {:ok, combat} <- process_game_action(socket, {:skip_turn, player}) do
      # Get next player for debugging
      [next_player | _] = combat.queue

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

  def handle_event("modal", %{"action" => "load_game"}, socket) do
    {:noreply, assign(socket, modal: :load_game)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, modal: nil)}
  end

  def handle_event("load_game_state", %{"game_state" => encoded_state}, socket) do
    case StateSave.decode(encoded_state) do
      {:ok, combat} ->
        grid = combat.grid
        characters = combat.queue

        # Create the game state with our combat struct
        game_state = %{
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
end
