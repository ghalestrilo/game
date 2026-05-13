defmodule GameWeb.CombatLive do
  use Phoenix.LiveComponent
  import GameWeb.CoreComponents
  alias Phoenix.LiveView.JS

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-full flex flex-row h-screen">
      <!-- HUD -->
      <.live_component
        module={GameWeb.CombatHUD}
        id="combat-hud"
        game_state={@game_state}
        action_log={@action_log}
        current_player={@current_player}
        game_mode={Map.get(assigns, :game_mode)}
      />

      <!-- Game area -->
      <div class="flex-1 flex flex-col overflow-hidden">
        <%= if @game_state do %>
          <.live_component
            module={GameWeb.GameBoard}
            id="game-board-component"
            game_state={@game_state}
            current_player={@current_player}
          />
        <% end %>
      </div>

      <!-- Game Over Modal -->
      <.modal
        :if={@game_state && @game_state.combat && @game_state.combat.state == :game_over}
        id="game-over-modal"
        show={true}
        on_cancel={JS.push("enter_shop")}
      >
        <div class="text-center">
          <h2 class="text-3xl font-bold mb-4">Combat Complete!</h2>
          <div class="mb-6">
            <% remaining_teams =
              @game_state.combat.queue |> Enum.reject(&is_nil/1) |> Enum.map(& &1.team) |> Enum.uniq() %>
            <%= if length(remaining_teams) == 1 do %>
              <p class="text-xl mb-2">Team {Enum.at(remaining_teams, 0)} is victorious!</p>
            <% else %>
              <p class="text-xl mb-2">Combat has ended</p>
            <% end %>
          </div>
          <div class="mb-6">
            <h3 class="text-lg font-semibold mb-2">Surviving Characters:</h3>
            <ul class="space-y-2">
              <%= for character <- Game.CombatState.get_current_queue(@game_state.combat), character != nil do %>
                <li class="flex items-center justify-center gap-2">
                  <span class="font-medium">{character.name}</span>
                  <span class="text-base-content/60">({character.class})</span>
                  <span class="text-sm">
                    HP: {character.hp}/{Game.Character.get_max_hp(character)}
                  </span>
                </li>
              <% end %>
            </ul>
          </div>
          <button phx-click="enter_shop" class="btn btn-secondary btn-lg">
            Continue to Shop
          </button>
        </div>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event("interact", params, socket) do
    send(self(), {:parent_event, "interact", params})
    {:noreply, socket}
  end

  def handle_event("enter_shop", params, socket) do
    send(self(), {:parent_event, "enter_shop", params})
    {:noreply, socket}
  end

  def handle_event("load_game_state", params, socket) do
    send(self(), {:parent_event, "load_game_state", params})
    {:noreply, socket}
  end
end
