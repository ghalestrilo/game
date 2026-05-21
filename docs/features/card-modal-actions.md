# Feature: Card Modal Actions

## Context

The `card_modal` component (`lib/game_web/components/core_components.ex`) is shared by three
features: Boosters, View Draw Pile, and View Discard Pile. It currently supports one interaction
mode: selecting a card (used by Boosters). The other two usages are read-only.

This feature adds an `enabled_actions` attribute — a list of atoms — that controls which action
buttons appear beneath each card. The four supported actions are:

- `:remove` — permanently remove the card from the player's deck
- `:cast` — play the card immediately outside the normal hand flow
- `:duplicate` — add a copy of the card to the draw pile
- `:steal` — move the card to the acting player's deck (used when viewing an opponent's pile)

Each card gets a `join` of `btn`-classed buttons below it, rendered only when
`enabled_actions` is non-empty.

---

## Implementation Plan

### 1. Extend `card_modal` with `enabled_actions`

**File:** `lib/game_web/components/core_components.ex`

Add one new attribute:

```elixir
attr :enabled_actions, :list, default: []
```

Pass it down to the `card` component (which will be extended in the next step):

```heex
<.card
  :for={{card, index} <- Enum.with_index(@displayed_cards)}
  card={card}
  index={index}
  selected={@selected_index == index}
  disabled={false}
  on_click={if @selectable, do: @on_select, else: nil}
  click_target={@click_target}
  enabled_actions={@enabled_actions}
/>
```

### 2. Extend the `card` component with action buttons

**File:** `lib/game_web/components/core_components.ex`

Add the attribute:

```elixir
attr :enabled_actions, :list, default: []
```

Render the action bar directly below the card body, before the hover-3d filler divs:

```heex
<div :if={@enabled_actions != []} class="join px-2 pb-2 pt-1 flex justify-center">
  <button
    :if={:remove in @enabled_actions}
    class="btn btn-xs join-item"
    phx-click="card_action"
    phx-value-action="remove"
    phx-value-card_index={@index}
    phx-target={@click_target}
  >
    Remove
  </button>
  <button
    :if={:cast in @enabled_actions}
    class="btn btn-xs join-item"
    phx-click="card_action"
    phx-value-action="cast"
    phx-value-card_index={@index}
    phx-target={@click_target}
  >
    Cast
  </button>
  <button
    :if={:duplicate in @enabled_actions}
    class="btn btn-xs join-item"
    phx-click="card_action"
    phx-value-action="duplicate"
    phx-value-card_index={@index}
    phx-target={@click_target}
  >
    Duplicate
  </button>
  <button
    :if={:steal in @enabled_actions}
    class="btn btn-xs join-item"
    phx-click="card_action"
    phx-value-action="steal"
    phx-value-card_index={@index}
    phx-target={@click_target}
  >
    Steal
  </button>
</div>
```

All four buttons fire the same `"card_action"` event with `action` and `card_index` params. The
handler in the parent LiveView/LiveComponent dispatches on `action`.

### 3. Add `card_action` event handlers in `CombatHud`

**File:** `lib/game_web/live/combat_hud.ex`

Add a handler that reads `action` and `card_index`, then delegates to `Game`:

```elixir
def handle_event("card_action", %{"action" => action, "card_index" => index_str}, socket) do
  index = String.to_integer(index_str)
  player_id = socket.assigns.current_player.id
  game_id = socket.assigns.game_id

  case action do
    "remove"    -> Game.remove_card_from_deck(game_id, player_id, index)
    "cast"      -> Game.cast_card(game_id, player_id, index)
    "duplicate" -> Game.duplicate_card(game_id, player_id, index)
    "steal"     -> Game.steal_card(game_id, player_id, index)
  end

  {:noreply, socket}
end
```

The draw/discard pile modals in `combat_hud.ex` that need actions pass `enabled_actions` and
`click_target={@myself}`:

```heex
<.card_modal
  id="draw-pile-modal"
  title="Draw Pile"
  cards={@game_state.combat.current_turn.player.cards.draw}
  on_cancel={hide_modal("draw-pile-modal")}
  enabled_actions={[:remove, :cast, :duplicate]}
  click_target={@myself}
/>
```

### 4. Implement `Game` action functions

**File:** `lib/game.ex`

Four new public functions, each taking `(game_id, player_id, card_index)`:

- `remove_card_from_deck/3` — deletes the card at `card_index` from the player's draw pile
- `cast_card/3` — applies the card's effects as if played from hand, then discards it
- `duplicate_card/3` — inserts a copy of the card at `card_index` into the draw pile
- `steal_card/3` — moves the card from the viewed character's pile to the current player's draw pile

Each follows the existing `GenServer.call(via(game_id), {:action, ...})` pattern and broadcasts
updated state to subscribers.

---

## TDD Plan

Write tests before implementing. Each test section below maps to a distinct layer.

### Test file: `test/game/card_management_test.exs`

This file already exists. Add a new `describe` block for each action:

```elixir
describe "remove_card_from_deck/3" do
  test "removes the card at the given index from the draw pile"
  test "does not affect other piles (hand, discard)"
  test "returns error when index is out of bounds"
end

describe "cast_card/3" do
  test "applies card effects to the current combat state"
  test "card is moved to discard pile after casting"
  test "casting a one-time-use card does not add it to discard"
end

describe "duplicate_card/3" do
  test "adds an identical copy of the card to the draw pile"
  test "original card remains at its index"
  test "copy is inserted (not appended) — draw pile length increases by 1"
end

describe "steal_card/3" do
  test "removes card from source character's draw pile"
  test "adds card to current player's draw pile"
  test "no-ops if source player is the same as current player"
end
```

### Test file: `test/game_web/live/combat_hud_test.exs` (new file)

LiveView integration tests using `Phoenix.LiveViewTest`:

```elixir
describe "card_action events" do
  test "remove sends card_action with action=remove and correct card_index"
  test "cast sends card_action with action=cast and correct card_index"
  test "duplicate sends card_action with action=duplicate and correct card_index"
  test "steal sends card_action with action=steal and correct card_index"
end
```

Use `render_click(view, "card_action", %{"action" => "remove", "card_index" => "0"})` and assert
the resulting HTML or side-effects.

### Test file: `test/game_web/components/core_components_test.exs` (new or existing)

Component-level rendering tests:

```elixir
describe "card_modal enabled_actions" do
  test "renders no action buttons when enabled_actions is []"
  test "renders only :remove button when enabled_actions is [:remove]"
  test "renders all four buttons when enabled_actions contains all atoms"
  test "action buttons carry correct phx-value-card_index for each card"
  test "action buttons carry correct phx-value-action attribute"
end
```

Use `Phoenix.LiveViewTest.render_component/2` or inline component rendering helpers.

---

## Critical Files

| File | Change |
|------|--------|
| `lib/game_web/components/core_components.ex` | Add `enabled_actions` attr to `card_modal` and `card`; render action button `join` in `card` |
| `lib/game_web/live/combat_hud.ex` | Add `handle_event("card_action", ...)` dispatcher; pass `enabled_actions` to draw/discard modals |
| `lib/game.ex` | Add `remove_card_from_deck/3`, `cast_card/3`, `duplicate_card/3`, `steal_card/3` |
| `test/game/card_management_test.exs` | New `describe` blocks for each action |
| `test/game_web/live/combat_hud_test.exs` | New file — LiveView event integration tests |
| `test/game_web/components/core_components_test.exs` | New or extended — component rendering tests for action buttons |

---

## Verification

1. Open the Draw Pile modal during combat — confirm action buttons appear below each card.
2. Click "Remove" on a card — confirm it disappears from the draw pile and is gone on next refresh.
3. Click "Cast" — confirm the card's effects fire and it moves to discard.
4. Click "Duplicate" — confirm the draw pile grows by one and the copy has the same name/effects.
5. Open the Booster modal — confirm no action buttons appear (no `enabled_actions` passed).
6. Pass `enabled_actions={[]}` explicitly — confirm no buttons render (same as default).
