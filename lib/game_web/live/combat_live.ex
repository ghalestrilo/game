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
    <div class=" mx-auto max-w-full p-4 mb-100">
      <div class="mb-4 flex gap-4">
        <button
          phx-click="reset"
          class="btn btn-primary"
        >
          Reset Game
        </button>
        <button
          phx-click="skip_turn"
          class="btn btn-success"
        >
          Skip Turn
        </button>
        <button
          phx-click="win_match"
          class="btn btn-warning"
        >
          Win Match
        </button>
        <button
          phx-click="modal"
          phx-value-action="load_game"
          class="btn btn-secondary"
        >
          Load Game State
        </button>
      </div>

      <%= if @game_state do %>
        <% queue = Game.CombatState.get_current_queue(@game_state.combat) %>
        <% rows = Game.Grid.to_rows(@game_state.combat.grid) %>
        <% pos = build_position_index(rows) %>
        <div class="flex flex-row gap-8">
          <!-- Combat State Panel -->
          <div class="mb-4 min-w-[300px] bg-base-200 p-4 rounded shadow">
            <h3 class="text-lg font-bold mb-2">Combat State</h3>
            <div class="text-md">
              <span class="font-semibold">State:</span>
              <span class="badge badge-info">
                {@game_state.combat.state}
              </span>
            </div>

            <%= if @game_state.combat.current_turn.player do %>
              <h3 class="text-lg font-bold mb-2">Current Player</h3>
              <div class="text-md mb-4">
                {@game_state.combat.current_turn.player.name} ({@game_state.combat.current_turn.player.class})
              </div>
            <% end %>

            <!-- Turn Queue Panel -->
            <div class="mt-4">
              <h3 class="text-lg font-bold mb-2">Turn Queue</h3>
              <ul class="text-sm">
                <%= for character <- queue, character != nil do %>
                  <li class="my-2 p-2 border border-base-content/20 rounded">
                    <div class="pb-1 flex gap-1">
                      <span
                        :for={hp <- 1..Game.Character.get_max_hp(character)}
                        class={"#{if hp > character.hp, do: "bg-base-300", else: "bg-error"} max-w-[20px] flex-1 h-2 rounded-[2px]"}
                      />
                    </div>
                    <div class="pb-1 flex gap-1">
                      <span
                        :for={ap <- 1..Game.Character.get_max_ap(character)}
                        class={"#{if ap > character.ap, do: "bg-base-300", else: "bg-warning"} max-w-[20px] flex-1 h-2 rounded-[2px]"}
                      />
                    </div>
                    <div class="pb-1 flex gap-1">
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
                    {inspect(character)}
                  </li>
                <% end %>
              </ul>
            </div>
          </div>

          <!-- Game board -->
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
                      if(current_player_at?(@game_state.combat, queue, {q, r, s}), do: "!bg-success/30")
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

        <div class="flex gap-8">
          <!-- Action log panel -->
          <div
            class="action-log bg-base-200 p-4 mt-8 rounded overflow-auto flex-1"
            style="max-height: 200px;"
          >
            <h3 class="text-lg font-bold mb-2">Action Log</h3>
            <ul class="list-disc pl-5">
              <%= for action <- @action_log do %>
                <li class="text-sm mb-1">{action}</li>
              <% end %>
            </ul>
          </div>

          <%= if @game_state.combat.current_turn.player &&
                 (@current_player == nil || @current_player.id == @game_state.combat.current_turn.player.id) do %>
            <div class="flex gap-4 flex-2 flex-row justify-between">
              <!-- Card piles status panel -->
              <div class="card-status-panel w-full bg-base-200 p-4 rounded">
                <div class="mb-3">
                  <h4 class="font-semibold">
                    Current Player: {@game_state.combat.current_turn.player.name}
                  </h4>
                </div>
                <div class="flex gap-4 flex-row justify-between items-stretch flex-1">
                  <div class="mb-3">
                    <h4 class="font-semibold">
                      Draw Pile: {length(@game_state.combat.current_turn.player.cards.draw)} cards
                    </h4>
                    <div class="text-xs text-base-content/50">
                      <%= for card <- @game_state.combat.current_turn.player.cards.draw do %>
                        <div class="card-tiny">{card.name}</div>
                      <% end %>
                    </div>
                  </div>

                  <div class="mb-3">
                    <h4 class="font-semibold">
                      Hand: {length(@game_state.combat.current_turn.player.cards.hand)} cards
                    </h4>
                    <div class="text-xs text-base-content/50">
                      <%= for card <- @game_state.combat.current_turn.player.cards.hand do %>
                        <div class="card-tiny">{card.name} (Cost: {card.cost})</div>
                      <% end %>
                    </div>
                  </div>

                  <div class="mb-3">
                    <h4 class="font-semibold">
                      Discard Pile: {length(@game_state.combat.current_turn.player.cards.discard)} cards
                    </h4>
                    <div class="text-xs text-base-content/50">
                      <%= for card <- @game_state.combat.current_turn.player.cards.discard do %>
                        <div class="card-tiny">{card.name}</div>
                      <% end %>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </div>

        <%= if @game_state.combat.current_turn.player &&
               (@current_player == nil || @current_player.id == @game_state.combat.current_turn.player.id) do %>
          <div class="card-row mt-4">
            <%= for {card, index} <- Enum.with_index(@game_state.combat.current_turn.player.cards.hand) do %>
              <.card
                selected={card == Map.get(@game_state.combat.current_turn, :card, nil)}
                index={index}
                card={card}
              />
            <% end %>
          </div>
        <% end %>
      <% end %>

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

          <button
            phx-click="enter_shop"
            class="btn btn-secondary btn-lg"
          >
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
      {left, top} -> "transform: translate(#{left - r + padding}px, calc(#{vertical_scaling} * #{top - r + padding}px));"
      nil -> "display: none;"
    end
  end

  defp character_bg(%{avatar_url: url}) when is_binary(url) and url != "",
    do: "!bg-[url('#{url}')]"

  defp character_bg(_), do: ""
end
