defmodule GameWeb.CombatLive do
  alias Game.Grid
  use Phoenix.LiveComponent
  import GameWeb.CoreComponents
  alias Phoenix.LiveView.JS
  alias Game

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-full flex flex-row h-screen">
      <!-- HUD -->
      <div class="fixed z-10 grid [grid-template-areas:'queue_empty_action'_'draw_hand_discard'] gap-4 w-full shrink-0 p-4 overflow-y-auto">
        <div :if={@game_state} class="bg-gray-800 max-w-64">
          <!-- Buttons -->
          <div class="[grid-area:hand] flex flex-wrap gap-2">
            <button phx-click="reset" class="btn btn-primary btn-sm">Reset Game</button>
            <button phx-click="skip_turn" class="btn btn-success btn-sm">Skip Turn</button>
            <button phx-click="win_match" class="btn btn-warning btn-sm">Win Match</button>
            <button phx-click="modal" phx-value-action="load_game" class="btn btn-secondary btn-sm">
              Load Game State
            </button>
          </div>

    <!-- Combat state -->
          <div :if={@game_state}>
            <span class="font-semibold text-sm">State:</span>
            <span class="badge badge-info badge-sm ml-1">{@game_state.combat.state}</span>
          </div>

    <!-- Turn Queue -->
          <div :if={@game_state}>
            <% queue = Game.CombatState.get_current_queue(@game_state.combat) %>
            <h3 class="text-base font-bold mb-2">Turn Queue</h3>
            <ul class="text-sm flex flex-col gap-2">
              <li
                :for={character <- Enum.filter(queue, fn character -> character != nil end)}
                class="p-2 border border-base-content/20 rounded"
              >
                <div class="font-medium mb-1">
                  {character.name}
                  <%= if character == @game_state.combat.current_turn.player do %>
                    <span class="badge badge-success badge-xs ml-1">current</span>
                  <% end %>
                </div>
                <div class="flex gap-1 mb-1">
                  <span
                    :for={hp <- 1..Game.Character.get_max_hp(character)}
                    class={"#{if hp > character.hp, do: "bg-base-300", else: "bg-error"} max-w-[20px] flex-1 h-2 rounded-[2px]"}
                  />
                </div>
                <div class="flex gap-1 mb-1">
                  <span
                    :for={ap <- 1..Game.Character.get_max_ap(character)}
                    class={"#{if ap > character.ap, do: "bg-base-300", else: "bg-warning"} max-w-[20px] flex-1 h-2 rounded-[2px]"}
                  />
                </div>
                <div class="flex gap-1">
                  <span
                    :for={
                      _shield <-
                        List.duplicate(
                          nil,
                          case Game.Character.get_status_effect(character, :shield) do
                            %{value: value} -> value
                            _ -> 0
                          end
                        )
                    }
                    class="bg-info max-w-[20px] flex-1 h-2 rounded-[2px]"
                  />
                </div>
              </li>
            </ul>
          </div>
        </div>

    <!-- Action Log -->
        <div class="[grid-area:action]">
          <h3 class="text-base font-bold mb-2">Action Log</h3>
          <div class="bg-base-300 rounded p-2 overflow-y-auto max-h-40 text-xs">
            <ul class="list-disc pl-4 flex flex-col gap-1">
              <li :for={action <- @action_log}>{action}</li>
            </ul>
          </div>
        </div>

    <!-- Card piles -->
        <%= if @game_state.combat.current_turn.player &&
                 (@current_player == nil || @current_player.id == @game_state.combat.current_turn.player.id) do %>
          <div class="[grid-area:draw] flex flex-col gap-3 text-xs">
            <h4 class=" font-semibold text-base-content/70 mb-1">
              Draw ({length(@game_state.combat.current_turn.player.cards.draw)})
            </h4>
            <%= for card <- @game_state.combat.current_turn.player.cards.draw do %>
              <div class="card-tiny">{card.name}</div>
            <% end %>
          </div>
          <div
            :if={
              get_in(@game_state, [:combat, :current_turn, :player]) &&
                (@current_player == nil ||
                   @current_player.id == @game_state.combat.current_turn.player.id)
            }
            class="[grid-area:hand] card-row"
          >
            <.card
              :for={{card, index} <- Enum.with_index(@game_state.combat.current_turn.player.cards.hand)}
              selected={card == Map.get(@game_state.combat.current_turn, :card, nil)}
              index={index}
              card={card}
            />
          </div>
          <div class="[grid-area:discard]">
            <h4 class="font-semibold text-base-content/70 mb-1">
              Discard ({length(@game_state.combat.current_turn.player.cards.discard)})
            </h4>
            <%= for card <- @game_state.combat.current_turn.player.cards.discard do %>
              <div class="card-tiny">{card.name}</div>
            <% end %>
          </div>
        <% end %>
      </div>

    <!-- Game area -->
      <div class="flex-1 flex flex-col overflow-hidden">
        <%= if @game_state do %>
          <% queue = Game.CombatState.get_current_queue(@game_state.combat) %>
          <% rows = Game.Grid.to_rows(@game_state.combat.grid) %>
          <% pos = build_position_index(rows) %>

    <!-- Board -->
          <div class="flex-1 flex items-center justify-center overflow-hidden mt-10">
            <div class="game-board">
              <!-- Map layer -->
              <%= for row <- rows do %>
                <div class="flex flex-row justify-center gap-2">
                  <%= for {q, r, s, _tile} <- row do %>
                    <div
                      phx-click="interact"
                      phx-value-target_position={"#{q}_#{r}_#{s}"}
                      class={[
                        "hex-cell border border-base-content/20 w-20 h-20 flex items-center justify-center bg-base-100",
                        if(within_movement_range?(@game_state.combat, {q, r, s}), do: "bg-warning/10"),
                        if(current_player_at?(@game_state.combat, queue, {q, r, s}),
                          do: "!bg-success/30"
                        )
                      ]}
                    >
                    </div>
                  <% end %>
                </div>
              <% end %>

    <!-- Entity layer -->
              <div class="absolute inset-0 pointer-events-none">
                <%= for character <- queue, character != nil do %>
                  <div
                    id={"character-#{character.id}"}
                    phx-key={to_string(character.id)}
                    class={[
                      "character absolute top-0 left-0 pointer-events-auto !bg-cover !bg-no-repeat",
                      character_bg(character)
                    ]}
                    data-character-id={character.id}
                    style={character_style(pos, character)}
                  >
                    <div class="character-name !mt-10 px-2 py-1 rounded-[8px] bg-black opacity-[0.6]">
                      {character.name}
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
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
  def handle_event("reset", params, socket) do
    send(self(), {:parent_event, "reset", params})
    {:noreply, socket}
  end

  def handle_event("pick_card", params, socket) do
    send(self(), {:parent_event, "pick_card", params})
    {:noreply, socket}
  end

  def handle_event("interact", params, socket) do
    send(self(), {:parent_event, "interact", params})
    {:noreply, socket}
  end

  def handle_event("skip_turn", params, socket) do
    send(self(), {:parent_event, "skip_turn", params})
    {:noreply, socket}
  end

  def handle_event("win_match", params, socket) do
    send(self(), {:parent_event, "win_match", params})
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

  def handle_event("modal", params, socket) do
    send(self(), {:parent_event, "modal", params})
    {:noreply, socket}
  end

  defp within_movement_range?(combat, coord) do
    combat.current_turn.player &&
      Grid.distance(
        combat.grid,
        coord,
        Game.CombatState.get_current_turn(combat).starting_position
      ) <= Game.CombatState.get_current_player(combat).movement_range
  end

  defp current_player_at?(combat, queue, coord) do
    combat.current_turn.player &&
      Enum.find(queue, fn c -> c && c.position == coord end) == combat.current_turn.player
  end

  defp build_position_index(rows) do
    cell = 80
    gap = 8
    step = cell + gap

    max_cols = rows |> Enum.map(&length/1) |> Enum.max()
    board_w = max_cols * cell + (max_cols - 1) * gap

    rows
    |> Enum.with_index()
    |> Enum.flat_map(fn {row, row_idx} ->
      n = length(row)
      row_w = n * cell + (n - 1) * gap
      x0 = (board_w - row_w) / 2

      row
      |> Enum.with_index()
      |> Enum.map(fn {{q, r, s, _}, col_idx} ->
        {{q, r, s}, {x0 + col_idx * step + cell / 2, row_idx * step + cell / 2}}
      end)
    end)
    |> Map.new()
  end

  defp character_style(pos, character) do
    padding = 20
    r = 32
    vertical_scaling = 0.92

    case Map.get(pos, character.position) do
      {left, top} ->
        "transform: translate(#{left - r + padding}px, calc(#{vertical_scaling} * #{top - r + padding}px));"

      nil ->
        "display: none;"
    end
  end

  defp character_bg(%{avatar_url: url}) when is_binary(url) and url != "",
    do: "!bg-[url('#{url}')]"

  defp character_bg(_), do: ""
end
