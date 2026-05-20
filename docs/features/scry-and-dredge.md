# Feature: Scry and Dredge Card Effects

## Context

Two new card effects to implement:

- **Scry X** — look at the top X cards of your draw pile, reorder them freely, they return to the
  top in the chosen order.
- **Dredge X** — pick X cards from your discard pile and move them to hand.

Both are card effects (follow the `CardEffect` protocol) that require player interaction — unlike
damage or heal which resolve instantly, they open a UI modal for the acting player to make choices.
This is the same pattern the existing booster pick flow uses (`card_modal` + `selectable`).

The roadmap also notes "implement card actions in card view dialog" — scry and dredge are the first
effects that need interactive UI, so they establish that pattern.

---

## Implementation Plan

### 1. Pending action state

Both effects cannot resolve in a single `process/3` call because they need player input. The
approach: `process/3` records a **pending action** on the combat state, the LiveView renders the
appropriate modal, the player makes their choice, and a follow-up event finalises the state.

Add a `pending_action` field to `CombatState`:

**File:** `lib/game/combat_state.ex`

```elixir
defstruct ...,
          pending_action: nil   # %{type: :scry | :dredge, player_id: id, cards: [...]} | nil
```

### 2. Scry effect

**New file:** `lib/game/combat/card_effects/scry.ex`

`process/3` takes the top X cards off the player's draw pile and stores them in `pending_action`:

```elixir
defmodule Game.Combat.CardEffects.Scry do
  defstruct type: :scry, value: 1, value_label: nil

  defimpl Game.Combat.CardEffect do
    def process(%{value: count}, _target, combat_state) do
      player = combat_state.current_turn.player
      {top_cards, remaining_draw} = Enum.split(player.cards.draw, count)

      updated_player = put_in(player.cards.draw, remaining_draw)
      updated_combat = put_in(combat_state, [:current_turn, :player], updated_player)

      %{updated_combat | pending_action: %{
        type: :scry,
        player_id: player.id,
        cards: top_cards
      }}
    end

    def animate(%{value: v}), do: %{label: "SCRY #{v}", color: :blue}
    def get_description(%{value: v}), do: "Look at the top #{v} cards and reorder them"
    def get_icon(_), do: "hero-eye-solid"
    def get_value_label(%{value_label: l}) when is_binary(l), do: l
    def get_value_label(%{value: v}), do: "#{v}"
    def params(_), do: ["value"]
  end
end
```

**Resolve event** — when the player submits their chosen order, call a new function:

```elixir
# lib/game/combat_state.ex
def resolve_scry(combat, ordered_card_ids) do
  pending = combat.pending_action
  reordered = Enum.sort_by(pending.cards, &Enum.find_index(ordered_card_ids, fn id -> id == &1.id end))
  player = combat.current_turn.player
  updated_player = put_in(player.cards.draw, reordered ++ player.cards.draw)
  combat
  |> put_in([:current_turn, :player], updated_player)
  |> Map.put(:pending_action, nil)
end
```

### 3. Dredge effect

**New file:** `lib/game/combat/card_effects/dredge.ex`

`process/3` stores a pending action with the full discard pile as candidates; the player picks up
to X of them:

```elixir
defmodule Game.Combat.CardEffects.Dredge do
  defstruct type: :dredge, value: 1, value_label: nil

  defimpl Game.Combat.CardEffect do
    def process(%{value: count}, _target, combat_state) do
      player = combat_state.current_turn.player

      %{combat_state | pending_action: %{
        type: :dredge,
        player_id: player.id,
        count: count,
        cards: player.cards.discard
      }}
    end

    def animate(%{value: v}), do: %{label: "DREDGE #{v}", color: :green}
    def get_description(%{value: v}), do: "Pick #{v} cards from your discard pile"
    def get_icon(_), do: "hero-arrow-uturn-up-solid"
    def get_value_label(%{value_label: l}) when is_binary(l), do: l
    def get_value_label(%{value: v}), do: "#{v}"
    def params(_), do: ["value"]
  end
end
```

**Resolve event:**

```elixir
# lib/game/combat_state.ex
def resolve_dredge(combat, selected_card_ids) do
  pending = combat.pending_action
  player = combat.current_turn.player
  {picked, remaining_discard} = Enum.split_with(player.cards.discard, &(&1.id in selected_card_ids))
  updated_player = player
    |> put_in([Access.key(:cards), :hand], player.cards.hand ++ picked)
    |> put_in([Access.key(:cards), :discard], remaining_discard)
  combat
  |> put_in([:current_turn, :player], updated_player)
  |> Map.put(:pending_action, nil)
end
```

### 4. Register both effects

**File:** `lib/game/card.ex` — `@effect_types` map

```elixir
"scry"   => CardEffects.Scry,
"dredge" => CardEffects.Dredge,
```

### 5. UI: scry modal (reorder cards)

**File:** `lib/game_web/live/combat_hud.ex` (or `game_live.ex`, wherever `pending_action` is surfaced)

Scry needs an ordered drag-or-click reorder UI. The simplest approach without drag-and-drop: render
the cards as a numbered list and let the player click them in the order they want on top (first
click = top of deck). Track selection order client-side or in socket assigns.

Add a modal rendered when `@game_state.combat.pending_action` is `%{type: :scry, player_id: current_player.id}`:

```heex
<.modal :if={scry_pending?(@game_state, @current_player)} id="scry-modal" show={true}>
  <h2>Scry — choose order (first = top of deck)</h2>
  <div class="flex flex-wrap gap-4 justify-center py-4">
    <.card
      :for={{card, index} <- Enum.with_index(scry_cards(@game_state))}
      card={card}
      index={index}
      on_click="scry_pick"
      click_target={@myself}
    />
  </div>
  <p class="text-sm text-base-content/60">
    Order chosen: {@scry_order |> length()} / {scry_cards(@game_state) |> length()} selected
  </p>
</.modal>
```

Socket assigns: `scry_order: []` (list of card ids in chosen order, built up as player clicks).

Event handler:

```elixir
def handle_event("scry_pick", %{"card_id" => id}, socket) do
  order = socket.assigns.scry_order
  id = String.to_integer(id)
  new_order = if id in order, do: List.delete(order, id), else: order ++ [id]

  # If all cards placed, auto-submit
  total = length(get_in(socket.assigns.game_state.combat.pending_action.cards))
  if length(new_order) == total do
    Game.resolve_scry(socket.assigns.game_pid, new_order)
    {:noreply, assign(socket, scry_order: [])}
  else
    {:noreply, assign(socket, scry_order: new_order)}
  end
end
```

Add `Game.resolve_scry/2` to `lib/game.ex` (GenServer call that runs `CombatState.resolve_scry/2`
and broadcasts).

### 6. UI: dredge modal (pick cards from discard)

Use the existing `card_modal` component with `selectable: true`. The player picks up to `count`
cards; submit when done.

```heex
<.card_modal
  :if={dredge_pending?(@game_state, @current_player)}
  id="dredge-modal"
  show={true}
  title="Dredge"
  subtitle={"Pick up to #{dredge_count(@game_state)} cards from your discard"}
  cards={dredge_cards(@game_state)}
  ordered={true}
  selectable={true}
  on_select="dredge_pick"
  selected_index={nil}
/>
```

Track selected card ids in `dredge_selected: []`. When `length(selected) == count`, auto-submit.
Add a "Confirm" button that submits even if fewer than `count` were picked (player may dredge fewer
if they choose).

Event handler:

```elixir
def handle_event("dredge_pick", %{"card_id" => id}, socket) do
  id = String.to_integer(id)
  selected = socket.assigns.dredge_selected
  count = get_in(socket.assigns.game_state.combat.pending_action.count)
  new_selected = toggle(selected, id)

  if length(new_selected) >= count do
    Game.resolve_dredge(socket.assigns.game_pid, new_selected)
    {:noreply, assign(socket, dredge_selected: [])}
  else
    {:noreply, assign(socket, dredge_selected: new_selected)}
  end
end

def handle_event("dredge_confirm", _, socket) do
  Game.resolve_dredge(socket.assigns.game_pid, socket.assigns.dredge_selected)
  {:noreply, assign(socket, dredge_selected: [])}
end
```

---

## Critical Files

| File | Change |
|------|--------|
| `lib/game/combat_state.ex` | Add `pending_action: nil` field; add `resolve_scry/2` and `resolve_dredge/2` |
| `lib/game/combat/card_effects/scry.ex` | New file |
| `lib/game/combat/card_effects/dredge.ex` | New file |
| `lib/game/card.ex` | Register `"scry"` and `"dredge"` in `@effect_types` |
| `lib/game.ex` | Add `resolve_scry/2` and `resolve_dredge/2` GenServer calls + handlers |
| `lib/game_web/live/combat_hud.ex` or `game_live.ex` | Render scry and dredge modals when `pending_action` matches; handle `scry_pick`, `dredge_pick`, `dredge_confirm` events |

---

## Verification

1. Create a card with a `scry 3` effect. Play it — confirm the top 3 draw cards appear in a modal.
   Click them in an order; confirm they return to the top of the draw pile in that order.
2. Create a card with a `dredge 2` effect. Discard some cards first, then play it — confirm the
   discard pile appears in a modal. Select 2 cards; confirm they move to hand and are gone from
   discard.
3. Confirm both modals only appear for the acting player (gate on `player_id == current_player.id`).
4. Confirm that after resolving, `pending_action` is `nil` and the turn can proceed normally.
