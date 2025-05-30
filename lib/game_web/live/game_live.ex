defmodule GameWeb.GameLive do
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
        <% mage = Enum.find(@game_state.characters, &(&1.class == :mage)) %>
        <div class="game-board">
          <%= for row <- Game.Grid.to_rows(@game_state.grid) do %>
            <div class="flex flex-row justify-center gap-2">
              <%= for {q, r, s, _tile} <- row do %>
                <div class="hex-cell border border-gray-300 w-16 h-16 flex items-center justify-center m-1 bg-white">
                  <%= if character = find_character(@game_state.characters, {q, r, s}) do %>
                    <div class={character_class(character)} data-character-id={character.id}>
                      <div class="character-name">{character.name}</div>
                      
                      <div class="character-hp text-gray-200">HP: {character.hp}</div>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
        
        <div class="card-row">
          <%= for card <- mage.hand || [] do %>
            <div phx-click="pick_card" phx-value-card-id={card.id} class="card">
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

    # Use the new 6x6 grid
    grid = Game.Grid.new({3, 3, 3})

    {:ok, _combat} = Game.init_combat(game_pid, updated_players, grid)
    game_state = Game.get_state(game_pid)
    {game_pid, game_state}
  end

  def handle_event("pick_card", params, socket) do
    {:ok, updated_combat} =
      Game.process_action(socket.assigns.game_pid, {:pick_card, params["card_id"]})

    {:noreply, assign(socket, game_state: updated_combat)}
  end
end
