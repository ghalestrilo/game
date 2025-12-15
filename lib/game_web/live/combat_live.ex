defmodule GameWeb.CombatLive do
  alias Game.Grid
  use Phoenix.LiveComponent
  import GameWeb.CoreComponents
  alias Phoenix.LiveView.JS
  alias Game
  alias Game.CombatState.StateSave
  alias Game.Fixtures

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class=" mx-auto max-w-full p-4">
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
        <button
          phx-click="win_match"
          class="bg-yellow-500 hover:bg-yellow-700 text-white font-bold py-2 px-4 rounded"
        >
          Win Match
        </button>
        <button
          phx-click="modal"
          phx-value-action="load_game"
          class="bg-purple-500 hover:bg-purple-700 text-white font-bold py-2 px-4 rounded"
        >
          Load Game State
        </button>
      </div>

      <%= if @game_state do %>
        <!-- Combat State Panel -->
        <div class="w-full flex flex-row gap-8">
          <div class="mb-4 min-w-[300px] bg-gray-100 p-4 rounded shadow inline-block">
            <h3 class="text-lg font-bold mb-2">Combat State</h3>
            <div class="text-md">
              <span class="font-semibold">State:</span>
              <span class="px-2 py-1 bg-blue-100 rounded text-blue-800 font-medium">
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
                <%= for character <- Game.CombatState.get_current_queue(@game_state.combat), character != nil do %>
                  <li class="my-2 p-2 border border-gray-100 rounded">
                    <div class="pb-1 flex gap-1">
                      <span
                        :for={hp <- 1..(Game.Character.get_max_hp(character))}
                        class={"#{if hp > character.hp, do: "bg-gray-300", else: "bg-green-300"} flex-1 h-1 rounded-[2px]"}
                      />
                    </div>
                    <div class="pb-1 flex gap-1">
                      <span
                        :for={ap <- 1..(Game.Character.get_max_ap(character))}
                        class={"#{if ap > character.ap, do: "bg-gray-300", else: "bg-yellow-300"} flex-1 h-1 rounded-[2px]"}
                      />
                    </div>
                    {inspect(character)}
                  </li>
                <% end %>
              </ul>
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
                        "hex-cell border border-gray-300 w-20 h-20 flex items-center justify-center  bg-white",
                        # If distance from `:starting_position` is within `:movement_range` highlight the hex cell
                        if(
                          @game_state.combat.current_turn.player &&
                          Grid.distance(
                            @game_state.combat.grid,
                            {q, r, s},
                            Game.CombatState.get_current_turn(@game_state.combat).starting_position
                          ) <=
                            Game.CombatState.get_current_player(@game_state.combat).movement_range,
                          do: "bg-yellow-50",
                          else: ""
                        ),
                        # If it's the current turn, highlight the hex cell
                        if(
                          @game_state.combat.current_turn.player &&
                          find_character(Game.CombatState.get_current_queue(@game_state.combat), {q, r, s}) ==
                            @game_state.combat.current_turn.player,
                          do: "!bg-green-200",
                          else: ""
                        )
                      ]
                    }
                  >
                    <%= if character = find_character(Game.CombatState.get_current_queue(@game_state.combat), {q, r, s}) do %>
                      <div class={character_class(character)} data-character-id={character.id}>
                        <div class="character-name !mt-10 px-2 py-1 rounded-[8px] bg-black opacity-[0.6]">
                          {character.name}
                        </div>
                        <!--
                        <div class="character-hp text-gray-200">HP: {character.hp}</div>
                        <div class="character-ap text-gray-200">AP: {character.ap}</div>
                        -->
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <div class="flex gap-8">
          <!-- Action log panel -->
          <div
            class="action-log bg-gray-100 p-4 mt-8 rounded overflow-auto flex-1"
            style="max-height: 200px;"
          >
            <h3 class="text-lg font-bold mb-2">Action Log</h3>
            <ul class="list-disc pl-5">
              <%= for action <- @action_log do %>
                <li class="text-sm mb-1">{action}</li>
              <% end %>
            </ul>
          </div>

          <%= if @game_state.combat.current_turn.player do %>
            <div class="flex gap-4 flex-2 flex-row justify-between">
              <!-- Card piles status panel -->
              <div class="card-status-panel w-full bg-gray-100 p-4 rounded">
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
              </div>
            </div>
          <% end %>
        </div>

        <%= if @game_state.combat.current_turn.player do %>
          <div class="card-row mt-4">
            <%= for {card, index} <- Enum.with_index(@game_state.combat.current_turn.player.cards.hand) do %>
              <div :if={false}
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

                <div class="card-effect">Cost: {card.cost} | {inspect(card.effects)}</div>
              </div>
              <.card
                selected={card == Map.get(@game_state.combat.current_turn, :card, nil)}
                index={index}
                card={card} />
            <% end %>
          </div>
        <% end %>
      <% end %>
      <%!--
      <div :if={@game_state != nil} class="">
        <details>
          <summary>Current Encoded Game State</summary>
          <p class="break-words">{Game.CombatState.StateSave.encode(@game_state.combat)}</p>
        </details>

        <details>
          <summary>Current Game State</summary>
          <p>{Jason.encode!(@game_state)}</p>
        </details>
      </div> --%>

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
            <% remaining_teams = @game_state.combat.queue |> Enum.reject(&is_nil/1) |> Enum.map(& &1.team) |> Enum.uniq() %>
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
                  <span class="text-gray-600">({character.class})</span>
                  <span class="text-sm">HP: {character.hp}/{Game.Character.get_max_hp(character)}</span>
                </li>
              <% end %>
            </ul>
          </div>

          <button
            phx-click="enter_shop"
            class="bg-purple-500 hover:bg-purple-700 text-white font-bold py-3 px-6 rounded-lg text-lg"
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

  defp find_character(characters, position) do
    Enum.find(characters, fn char -> char.position == position end)
  end

  defp character_class(%{class: class}),
    do: "character !bg-cover !bg-no-repeat #{get_class_bg(to_string(class))}"

  defp get_class_bg("bard"), do: "!bg-[url('/images/cat-bard.png')]"
  defp get_class_bg("cleric"), do: "!bg-[url('/images/cat-cleric.png')]"
  defp get_class_bg("druid"), do: "!bg-[url('/images/cat-druid.png')]"
  defp get_class_bg("fighter"), do: "!bg-[url('/images/cat-fighter.png')]"
  defp get_class_bg("mage"), do: "!bg-[url('/images/cat-mage.png')]"
  defp get_class_bg("monk"), do: "!bg-[url('/images/cat-monk.png')]"
  defp get_class_bg("paladin"), do: "!bg-[url('/images/cat-paladin.png')]"
  defp get_class_bg("ranger"), do: "!bg-[url('/images/cat-ranger.png')]"
  defp get_class_bg("sorcerer"), do: "!bg-[url('/images/cat-sorcerer.png')]"
  defp get_class_bg("rogue"), do: "!bg-[url('/images/cat-rogue.png')]"
  defp get_class_bg("warlock"), do: "!bg-[url('/images/cat-warlock.png')]"
  defp get_class_bg(_), do: "!bg-none"
end
