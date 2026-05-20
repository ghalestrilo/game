# Feature: Additional Key Support

## Context

The game already handles: number keys (1-9) to select cards, Space to confirm a target, w/s to
cycle targets, and movement keys. This feature adds:

- **Esc** — deselect the currently selected card (when `state: :card_selected`)
- **Left/Right** — cycle through cards in hand (when a card is selected or not)
- **Up/Down** — cycle through valid targets (replacing w/s, which stay for compatibility)
- **Target highlighting** — visually mark the keyboard-selected target on the board

The HUD is already `fixed` (not scroll-based), so "make header sticky" means ensuring the turn
queue panel doesn't get clipped/scrolled out of view when the card hand or action log grows. This
is a CSS-only adjustment.

---

## Implementation Plan

### 1. Esc to deselect card

**File:** `lib/game_web/live/game_live.ex`

Add a clause before the existing `card_selected` key handlers that catches `"Escape"`:

```elixir
def handle_event("handle_keys", %{"key" => "Escape"},
    %{assigns: %{game_state: %{combat: %{state: :card_selected} = combat}}} = socket) do
  card = combat.current_turn.card
  CombatController.dispatch(socket, %{type: :pick_card, card: card})
  # Dispatching pick_card with the already-selected card toggles it off (existing behaviour in combat.ex:272-279)
end
```

### 2. Left/Right to cycle cards in hand

**File:** `lib/game_web/live/game_live.ex`

Add a `keyboard_card_index` assign (default `0`) alongside the existing `keyboard_target_index`.

Add handlers for `"ArrowLeft"` and `"ArrowRight"` — active in both `:running` and `:card_selected`
states (so the player can browse cards before committing to a target):

```elixir
def handle_event("handle_keys", %{"key" => key}, socket) when key in ["ArrowLeft", "ArrowRight"] do
  hand = socket.assigns.game_state.combat.current_turn.player.cards.hand
  count = length(hand)

  if count == 0 do
    {:noreply, socket}
  else
    delta = if key == "ArrowRight", do: 1, else: -1
    new_index = rem(socket.assigns.keyboard_card_index + delta + count, count)
    card = Enum.at(hand, new_index)

    socket = assign(socket, keyboard_card_index: new_index)
    CombatController.dispatch(socket, %{type: :pick_card, card: card})
  end
end
```

Place this clause before the catch-all `handle_keys` handler so it takes priority.

### 3. Up/Down to cycle targets

**File:** `lib/game_web/live/game_live.ex`

Extend the existing `when key in ["s", "w"]` clause to also accept `"ArrowDown"` and `"ArrowUp"`:

```elixir
def handle_event("handle_keys", %{"key" => key},
    %{assigns: %{game_state: %{combat: %{state: :card_selected} = combat}}} = socket)
    when key in ["s", "w", "ArrowDown", "ArrowUp"] do
  targets = keyboard_targets(combat)
  count = length(targets)

  if count == 0 do
    {:noreply, socket}
  else
    delta = if key in ["s", "ArrowDown"], do: 1, else: -1
    new_index = rem(socket.assigns.keyboard_target_index + delta + count, count)
    {_, target} = Enum.at(targets, new_index)

    {:noreply,
     socket
     |> assign(keyboard_target_index: new_index)
     |> push_event("highlight-tile", %{coord: encode_coord(target.position)})}
  end
end
```

### 4. Target highlighting

The `push_event("highlight-tile", ...)` already works — `BoardTileClasses.js` handles it and
applies `blast-preview` styling. No additional work needed for keyboard-driven target highlighting.

For mouse hover, targets are already highlighted via the overlay classes (`ring-2 ring-inset
ring-error/20 bg-error/5` for valid tiles). The keyboard-selected target gets the additional
`blast-preview` scale effect on top of that, which is sufficient visual distinction.

### 5. Make turn queue header non-clipping (CSS only)

**File:** `lib/game_web/live/combat_hud.ex`

The outer container is `fixed` with `h-[133%]`. The turn queue is in `[grid-area:queue]` and can
overflow when many characters are in the queue. The action log is already `overflow-y-scroll`.

Add `overflow-y-auto` and a `max-h` cap to the queue list container so it scrolls internally
rather than pushing other grid areas:

```heex
<ul class="max-h-[calc(100vh-650px)] text-sm flex flex-col gap-3 overflow-y-scroll overflow-x-clip">
```

This line already exists (line 173) — verify it is applied to the right element and the value
`calc(100vh-650px)` is sufficient. Adjust the pixel offset if the header height differs.

---

## Critical Files

| File | Change |
|------|--------|
| `lib/game_web/live/game_live.ex` | Add `"Escape"` handler; add `"ArrowLeft"`/`"ArrowRight"` handler; extend `"s"`/`"w"` handler to include `"ArrowDown"`/`"ArrowUp"` |
| `lib/game_web/live/combat_hud.ex` | Verify/adjust `max-h` on queue list to prevent overflow |

No backend changes required — all key bindings are pure LiveView socket event handlers.

---

## Verification

1. Select a card — press Esc — confirm the card is deselected and combat returns to `:running`.
2. Press ArrowRight repeatedly — confirm cards in hand are cycled and each becomes selected.
3. With a card selected, press ArrowDown/ArrowUp — confirm the highlighted target changes on the
   board and `keyboard_target_index` advances correctly.
4. Press Space with a target highlighted — confirm the card is played at that target.
5. With many characters in the turn queue, confirm the queue panel scrolls internally and does not
   push the card hand off-screen.
