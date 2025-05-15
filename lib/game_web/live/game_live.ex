defmodule GameWeb.GameLive do
  use GameWeb, :live_view
  alias Game
  alias Game.Fixtures

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      {:ok, game_pid} = Game.start_link()

      # Initialize the game state with fixtures
      combat = Fixtures.basic_combat()
      {:ok, _combat} = Game.init_combat(game_pid, combat.players, combat.grid)
      game_state = Game.get_state(game_pid)

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
    # Reset using the fixtures
    combat = Fixtures.basic_combat()
    {:ok, _combat} = Game.init_combat(socket.assigns.game_pid, combat.players, combat.grid)
    game_state = Game.get_state(socket.assigns.game_pid)

    {:noreply, assign(socket, game_state: game_state)}
  end

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
          <%= for {q, r, s} <- get_visible_tiles(@game_state.grid) do %>
            <div class="hex-cell" style={get_hex_position(q, r)}>
              <%= if character = find_character(@game_state.characters, {q, r, s}) do %>
                <div class="character" data-character-id={character.id}>
                  {character.name}
                </div>
              <% end %>
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
    # Convert cube coordinates to pixel position
    # Horizontal spacing
    x = q * 90
    # Vertical spacing (adjusted for hex height)
    y = r * 78

    # Offset every other row
    y = if rem(q, 2) == 0, do: y, else: y + 39

    "transform: translate(#{x}px, #{y}px)"
  end
end
