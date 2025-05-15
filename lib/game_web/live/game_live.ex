defmodule GameWeb.GameLive do
  use GameWeb, :live_view
  alias Game

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      {:ok, game_pid} = Game.start_link()

      # Initialize the game state immediately
      grid = %Game.Grid{}

      characters = [
        %Game.Character{id: 1, position: {0, 0}},
        %Game.Character{id: 2, position: {2, 2}}
      ]

      {:ok, _combat} = Game.init_combat(game_pid, characters, grid)
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
    # Create a simple grid and two characters for demonstration
    grid = %Game.Grid{}

    characters = [
      %Game.Character{id: 1, position: {0, 0}},
      %Game.Character{id: 2, position: {2, 2}}
    ]

    {:ok, _combat} = Game.init_combat(socket.assigns.game_pid, characters, grid)
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
          <%= for {row, row_idx} <- Enum.with_index(@game_state.grid.cells) do %>
            <div class="flex justify-center">
              <%= for {cell, col_idx} <- Enum.with_index(row) do %>
                <div class="hex-cell">
                  <%= if character = find_character(@game_state.characters, {row_idx, col_idx}) do %>
                    <div class="character" data-character-id={character.id}>
                      {character.id}
                    </div>
                  <% end %>
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
end
