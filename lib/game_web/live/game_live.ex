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
      <div class="mb-4">
        <button
          phx-click="reset"
          class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
        >
          Reset Game
        </button>
      </div>
      
      <%= if @game_state do %>
        <div class="game-board">
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
        
        <div class="card-row">
          <%= for {card, index} <- Enum.with_index(@game_state.combat.current_turn.hand) do %>
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
    combat = Fixtures.basic_combat()
    mage = Enum.find(combat.players, &(&1.class == :mage))

    mage_with_cards = %{
      mage
      | hand: [
          %Game.Card{
            id: 1,
            name: "Fireball",
            cost: 2,
            effect: {:damage, 8},
            range: 3,
            targeting: :single
          },
          %Game.Card{
            id: 2,
            name: "Heal",
            cost: 2,
            effect: {:heal, 5},
            range: 1,
            targeting: :single
          }
        ]
    }

    updated_players =
      Enum.map(combat.players, fn player ->
        if player.id == mage_with_cards.id, do: mage_with_cards, else: player
      end)

    grid = Game.Grid.new({3, 3, 3})

    {:ok, _combat} = Game.init_combat(game_pid, updated_players, grid)
    game_state = Game.get_state(game_pid)
    {game_pid, game_state}
  end

  def handle_event("pick_card", params, socket) do
    current_turn = socket.assigns.game_state.combat.current_turn
    card = current_turn.hand |> Enum.at(String.to_integer(params["card_index"]))

    combat =
      with {:ok, updated_combat} <-
             process_game_action(socket, {:pick_card, current_turn.player, card}) do
        updated_combat
      else
        {:error, error} ->
          dbg(error)
          socket.assigns.game_state.combat
      end

    dbg(combat)

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
    dbg(params)
    {:noreply, socket}
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
        dbg(error)
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
