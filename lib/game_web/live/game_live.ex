defmodule GameWeb.GameLive do
  alias Game.Grid
  use GameWeb, :live_view
  alias Game
  alias Game.Fixtures

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      {game_pid, game_state} = initialize_game()
      {:ok, assign(socket, game_pid: game_pid, game_state: game_state)}
    else
      {:ok, assign(socket, game_pid: nil, game_state: nil)}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("reset", _params, socket) do
    {game_pid, game_state} = initialize_game()
    {:noreply, assign(socket, game_pid: game_pid, game_state: game_state)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto p-4">
      <div class="mb-4 flex gap-4">
        <button
          phx-click="reset"
          class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
        >
          Reset Game
        </button>
        <button
          phx-click="skip_turn"
          class="bg-green-500 hover:bg-green-700 text-white font-bold py-2 px-4 rounded"
        >
          Skip Turn
        </button>
      </div>

      <%= if @game_state do %>
        <div class="flex">
          <!-- Card piles status panel -->
          <div class="card-status-panel w-64 bg-gray-100 p-4 mr-4 rounded">
            <h3 class="text-lg font-bold mb-2">Current Player</h3>
            <div class="text-md mb-4">
              {@game_state.combat.current_turn.player.name} ({@game_state.combat.current_turn.player.class})
            </div>

            <div class="mb-3">
              <h4 class="font-semibold">
                Draw Pile: {length(@game_state.combat.current_turn.player.cards.draw)} cards
              </h4>
              <div class="text-xs text-gray-500">
                <%= for card <- @game_state.combat.current_turn.player.cards.draw do %>
                  <div class="card-tiny">{card.name}</div>
                <% end %>
              </div>
            </div>

            <div class="mb-3">
              <h4 class="font-semibold">
                Hand: {length(@game_state.combat.current_turn.player.cards.hand)} cards
              </h4>
              <div class="text-xs text-gray-500">
                <%= for card <- @game_state.combat.current_turn.player.cards.hand do %>
                  <div class="card-tiny">{card.name} (Cost: {card.cost})</div>
                <% end %>
              </div>
            </div>

            <div class="mb-3">
              <h4 class="font-semibold">
                Discard Pile: {length(@game_state.combat.current_turn.player.cards.discard)} cards
              </h4>
              <div class="text-xs text-gray-500">
                <%= for card <- @game_state.combat.current_turn.player.cards.discard do %>
                  <div class="card-tiny">{card.name}</div>
                <% end %>
              </div>
            </div>
          </div>
          
    <!-- Game board -->
          <div class="game-board flex-1">
            <%= for row <- Game.Grid.to_rows(@game_state.combat.grid) do %>
              <div class="flex flex-row justify-center gap-2">
                <%= for {q, r, s, _tile} <- row do %>
                  <div
                    phx-click="interact"
                    phx-value-target_position={"#{q}_#{r}_#{s}"}
                    class={
                      [
                        "hex-cell border border-gray-300 w-16 h-16 flex items-center justify-center m-1 bg-white",
                        # If distance from `:starting_position` is within `:movement_range` highlight the hex cell
                        if(
                          Grid.distance(
                            @game_state.combat.grid,
                            {q, r, s},
                            @game_state.combat.current_turn.starting_position
                          ) <=
                            @game_state.combat.current_turn.player.movement_range,
                          do: "bg-yellow-50",
                          else: ""
                        ),
                        # If it's the current turn, highlight the hex cell
                        if(
                          find_character(@game_state.combat.players, {q, r, s}) ==
                            @game_state.combat.current_turn.player,
                          do: "!bg-green-200",
                          else: ""
                        )
                      ]
                    }
                  >
                    <%= if character = find_character(@game_state.combat.players, {q, r, s}) do %>
                      <div class={character_class(character)} data-character-id={character.id}>
                        <div class="character-name">{character.name}</div>

                        <div class="character-hp text-gray-200">HP: {character.hp}</div>

                        <div class="character-ap text-gray-200">AP: {character.ap}</div>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <div class="card-row mt-4">
          <%= for {card, index} <- Enum.with_index(@game_state.combat.current_turn.player.cards.hand) do %>
            <div
              phx-click="pick_card"
              phx-value-card_index={index}
              class={[
                "card",
                if(card == Map.get(@game_state.combat.current_turn, :card, nil),
                  do: "!bg-yellow-50",
                  else: ""
                )
              ]}
            >
              <div class="card-title">{card.name}</div>

              <div class="card-effect">Cost: {card.cost} | {inspect(card.effect)}</div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp find_character(characters, position) do
    Enum.find(characters, fn char -> char.position == position end)
  end

  defp get_visible_tiles(%{tiles: tiles}) do
    tiles
    |> Map.keys()
    |> Enum.sort_by(fn {q, r, s} -> {r, q} end)
  end

  defp get_hex_position(q, r) do
    # Regular hex geometry (pointy-topped)
    width = 60
    height = 52
    x = (q * (width * 0.75)) |> round()
    y = r * height + if rem(q, 2) == 1, do: height / 2, else: 0
    y = round(y)
    "transform: translate(#{x}px, #{y}px)"
  end

  defp character_class(%{class: :mage}), do: "character mage"
  defp character_class(%{class: :fighter}), do: "character warrior"
  defp character_class(_), do: "character"

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
      players: updated_players,
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

    {:noreply, assign(socket, game_state: %{socket.assigns.game_state | combat: combat})}
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
      IO.inspect(next_player.cards, label: "AFTER Play Card - Next Player Cards")

      {:noreply, assign(socket, game_state: %{socket.assigns.game_state | combat: combat})}
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
      {:noreply, assign(socket, game_state: %{socket.assigns.game_state | combat: combat})}
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
    IO.inspect(player.cards, label: "BEFORE Skip Turn - Player Cards")

    with {:ok, combat} <- process_game_action(socket, {:skip_turn, player}) do
      # Get next player for debugging
      [next_player | _] = combat.queue
      IO.inspect(next_player.cards, label: "AFTER Skip Turn - Next Player Cards")

      {:noreply, assign(socket, game_state: %{socket.assigns.game_state | combat: combat})}
    else
      {:error, error} ->
        socket =
          socket
          |> put_flash(:error, "#{error}")

        {:noreply, socket}
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
