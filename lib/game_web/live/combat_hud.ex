defmodule GameWeb.CombatHUD do
  use Phoenix.LiveComponent
  import GameWeb.CoreComponents

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed z-10 grid [grid-template-areas:'queue_._action'_'draw_hand_discard'] [grid-template-columns:280px_1fr_280px] [grid-template-rows:1fr_auto] gap-4 p-4 pointer-events-none origin-top-left scale-75 w-[133%] h-[133%] pb-12">
      <div
        :if={@game_state}
        class="[grid-area:queue] bg-gray-800 self-start pointer-events-auto p-2 rounded"
      >
        <!-- Buttons -->
        <div class="flex flex-wrap gap-2 mb-2">
          <button phx-click="reset" phx-target={@myself} class="btn btn-primary btn-sm">Reset</button>
          <button phx-click="skip_turn" phx-target={@myself} class="btn btn-success btn-sm">
            Skip Turn
          </button>
          <button phx-click="win_match" phx-target={@myself} class="btn btn-warning btn-sm">
            Win Match
          </button>
        </div>

    <!-- Combat state -->
        <div :if={false}>
          <span class="font-semibold text-sm">State:</span>
          <span class="badge badge-info badge-sm ml-1">{@game_state.combat.state}</span>
        </div>

    <!-- Turn Queue // @TODO: refactor this, create a .character_queue_card component (same_team?, current?, stats) and a queue display component which groups those in the current stacked layout -->
        <div>
          <% queue = Game.CombatState.get_current_queue(@game_state.combat) %>
          <h3 class="text-base font-bold mb-2">Next up</h3>
          <ul class="text-sm flex flex-col gap-2">
            <li
              :for={character <- Enum.filter(queue, fn character -> character != nil end)}
              class={[
                "p-2 border border-base-content/20 rounded flex items-center gap-2",
                if(same_team?(character, @current_player), do: "flex-row", else: "flex-row-reverse")
              ]}
            >
              <%= if character.avatar_url && character.avatar_url != "" do %>
                <img src={character.avatar_url} class="w-10 h-10 rounded-full object-cover flex-shrink-0" />
              <% else %>
                <div class="w-10 h-10 rounded-full bg-base-300 flex-shrink-0" />
              <% end %>
              <div class={["flex-1 min-w-0",
              if(same_team?(character, @current_player), do: "items-start", else: "items-end text-end")
              ]}>
                <div class="font-medium mb-1">
                  {character.name}
                  <%= if character == @game_state.combat.current_turn.player do %>
                    <span class="badge badge-success badge-xs ml-1">current</span>
                  <% end %>
                </div>
                <div class={["flex gap-1 mb-1", if(same_team?(character, @current_player), do: "justify-start", else: "justify-end")]}>
                  <span
                    :for={hp <- 1..Game.Character.get_max_hp(character)}
                    class={"#{if hp > character.hp, do: "bg-base-300", else: "bg-error"} max-w-[20px] flex-1 h-2 rounded-[2px]"}
                  />
                </div>
                <div class={["flex gap-1 mb-1", if(same_team?(character, @current_player), do: "justify-start", else: "justify-end")]}>
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
              </div>
            </li>
          </ul>
        </div>
      </div>

    <!-- Action Log -->
      <div class="[grid-area:action] pointer-events-auto">
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
        <div class="[grid-area:draw] flex flex-col gap-3 text-xs pointer-events-auto">
          <h4 class="font-semibold text-base-content/70 mb-1">
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
          class="[grid-area:hand] card-row pointer-events-auto"
        >
          <.card
            :for={{card, index} <- Enum.with_index(@game_state.combat.current_turn.player.cards.hand)}
            selected={card == Map.get(@game_state.combat.current_turn, :card, nil)}
            disabled={not Game.Card.selectable?(card, @game_state.combat)}
            index={index}
            card={card}
            click_target={@myself}
          />
        </div>
        <div class="[grid-area:discard] pointer-events-auto">
          <h4 class="font-semibold text-base-content/70 mb-1">
            Discard ({length(@game_state.combat.current_turn.player.cards.discard)})
          </h4>
          <%= for card <- @game_state.combat.current_turn.player.cards.discard do %>
            <div class="card-tiny">{card.name}</div>
          <% end %>
        </div>
      <% end %>
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

  def handle_event("skip_turn", params, socket) do
    send(self(), {:parent_event, "skip_turn", params})
    {:noreply, socket}
  end

  def handle_event("win_match", params, socket) do
    send(self(), {:parent_event, "win_match", params})
    {:noreply, socket}
  end

  def handle_event("modal", params, socket) do
    send(self(), {:parent_event, "modal", params})
    {:noreply, socket}
  end

  defp same_team?(_character, nil), do: true
  defp same_team?(character, current_player), do: character.team == current_player.team
end
