defmodule GameWeb.CombatHUD do
  use Phoenix.LiveComponent
  import GameWeb.CoreComponents

  @team_colors ~w(
    border-sky-500
    border-rose-500
    border-emerald-500
    border-amber-500
    border-violet-500
    border-orange-500
    border-teal-500
    border-pink-500
  )

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed z-10 grid max-w-full [grid-template-areas:'queue_game_action'_'draw_hand_discard'] [grid-template-columns:320px_auto_280px] [grid-template-rows:1fr_auto] gap-4 p-4 pointer-events-none origin-top-left  w-[133%] h-[133%] pb-12">
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

        <.character_turn_queue
          combat={@game_state.combat}
          current_player={@current_player}
        />
      </div>
      
    <!-- Action Log -->
      <div class="[grid-area:action] pointer-events-auto min-w-[320px] min-h-full">
        <h3 class="text-base font-bold mb-2">Action Log</h3>
        <ul class="timeline timeline-vertical min-h-full">
          <li
            :for={{action, index} <- Enum.with_index(@action_log)}
            class="![grid-template-columns:1fr_16px] mr-8"
          >
            <hr :if={index > 0} />
            <div class="timeline-start timeline-box">{action}</div>
            <div class="timeline-middle min-w-4 min-h-4 rounded-full bg-base-300"></div>
            <hr :if={index < Enum.count(@action_log) - 1} />
          </li>
        </ul>
      </div>
      
    <!-- Card piles -->
      <%= if Map.get(assigns, :game_mode, nil) == :sandbox || (@game_state.combat.current_turn.player &&
               (@current_player == nil || @current_player.id == @game_state.combat.current_turn.player.id)) do %>
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
            Map.get(assigns, :game_mode, nil) == :sandbox ||
              (get_in(@game_state, [:combat, :current_turn, :player]) &&
                 (@current_player == nil ||
                    @current_player.id == @game_state.combat.current_turn.player.id))
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

  attr :combat, :map, required: true
  attr :current_player, :map, default: nil

  defp character_turn_queue(assigns) do
    ~H"""
    <div>
      <% [current | queue] = Game.CombatState.get_current_queue(@combat) %>
      <h3 class="text-base font-bold mb-2">Current turn</h3>
      <.character_queue_card
        character={current}
        current_player={@current_player}
        current={true}
      />
      <h3 class="text-base font-bold mt-2">Next up</h3>
      <ul class="text-sm flex flex-col gap-3">
        <.character_queue_card
          :for={character <- Enum.filter(queue, &(&1 != nil))}
          character={character}
          current_player={@current_player}
          current={character == @combat.current_turn.player}
        />
      </ul>
    </div>
    """
  end

  attr :character, :map, required: true
  attr :current_player, :map, default: nil
  attr :current, :boolean, required: true

  defp character_queue_card(assigns) do
    assigns =
      assign(assigns,
        same_team: same_team?(assigns.character, assigns.current_player),
        is_self: is_self?(assigns.character, assigns.current_player)
      )

    ~H"""
    <li class={[
      "p-3 border-2 rounded-lg flex items-start gap-2 transition-all duration-300",
      team_ring_class(@character.team),
      if(@is_self, do: "bg-yellow-400/15", else: "bg-base-200"),
      if(@same_team, do: "flex-row", else: "flex-row-reverse"),
      if(@current, do: "shadow-md animate-pulse", else: "scale-90")
    ]}>
      <%= if @character.avatar_url && @character.avatar_url != "" do %>
        <img src={@character.avatar_url} class="w-10 h-10 rounded-full object-cover flex-shrink-0" />
      <% else %>
        <div class="w-10 h-10 rounded-full bg-base-300 flex-shrink-0" />
      <% end %>
      <div class={["flex-1 min-w-0", if(@same_team, do: "items-start", else: "items-end text-end")]}>
        <div class={["flex gap-1 mb-1 items-center", if(@same_team, do: "", else: "flex-row-reverse")]}>
          <span>{@character.name}</span>
          <span class="badge badge-soft badge-sm ml-auto">
            <.icon name="hero-rectangle-stack-mini" class="size-4 px-0" />
            {Enum.count(@character.cards.draw)} / {Enum.count(@character.cards.hand)} / {Enum.count(
              @character.cards.discard
            )}
          </span>
        </div>
        <% eff_max_hp = Game.Character.effective_attribute(@character, "max_hp") %>
        <div class={[
          "flex items-center gap-0.5 mb-1",
          if(@same_team, do: "", else: "flex-row-reverse")
        ]}>
          <span class="badge badge-success badge-soft  px-1 min-w-fit">
            {@character.hp} / {@character.max_hp}
          </span>
          <progress class="progress progress-success" value={@character.hp} max={@character.max_hp}>
          </progress>
          <span
            :for={hp <- 1..eff_max_hp}
            :if={false}
            class={[
              "max-w-[20px] flex-1 h-2 rounded-[2px] ring-1 ring-inset ring-success",
              cond do
                hp > @character.hp -> "bg-base-300"
                hp > @character.max_hp -> "bg-success/50 ring-none"
                true -> "bg-success"
              end
            ]}
          />
        </div>
        <% eff_max_ap = Game.Character.effective_attribute(@character, "max_ap") %>
        <div class={["flex items-center gap-1 mb-1", if(@same_team, do: "", else: "flex-row-reverse")]}>
          <span class="badge badge-soft badge-warning px-1">
            {@character.ap} / {@character.max_ap}
          </span>
          <span
            :for={ap <- 1..eff_max_ap}
            class={[
              "max-w-[20px] flex-1 h-2 rounded-[2px]",
              cond do
                ap > @character.ap -> "bg-base-300"
                ap > @character.max_ap -> "bg-success"
                true -> "bg-warning"
              end
            ]}
          />
        </div>
        <div class={[
          "flex gap-1",
          if(@same_team, do: "justify-start", else: "justify-end flex-row-reverse")
        ]}>
          <span
            :for={
              _shield <-
                List.duplicate(
                  nil,
                  case Game.Character.get_status_effect(@character, :shield) do
                    %{value: value} -> round(value)
                    _ -> 0
                  end
                )
            }
            class="bg-info max-w-[20px] flex-1 h-2 rounded-[2px]"
          />
        </div>
        <div class={[
          "flex flex-wrap gap-1 mt-1",
          if(@same_team, do: "justify-start", else: "justify-end")
        ]}>
          <span
            :for={effect <- Enum.reject(@character.status_effects, &(&1.type == :shield))}
            class="badge badge-base badge-xs height-fit max-h-unset !h-fit"
          >
            {Game.StatusEffect.get_display_text(effect)}
          </span>
        </div>
      </div>
    </li>
    """
  end

  defp team_ring_class(team) when is_integer(team) do
    Enum.at(@team_colors, rem(team, length(@team_colors)))
  end

  defp team_ring_class(team) do
    index = team |> String.to_charlist() |> Enum.sum() |> rem(length(@team_colors))
    Enum.at(@team_colors, index)
  end

  defp same_team?(_character, nil), do: true

  defp same_team?(character, current_player),
    do: to_string(character.team) == to_string(current_player.team)

  defp is_self?(_character, nil), do: false
  defp is_self?(character, current_player), do: character.id == current_player.id
end
