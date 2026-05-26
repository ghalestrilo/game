# Feature: Action Log Card Identity & Hover Tooltip

## Context

The action log in `combat_hud.ex` displays a vertical timeline of plain strings. When a player plays a card, the entry reads `"Player played a card"` — no card identity is shown. Hovering an entry reveals nothing extra.

This feature:
1. Shows the card name in play-card log entries.
2. Attaches the card struct to each log entry so the HUD can render a full `.card` hover overlay.

---

## Data Model

Action log entries change from plain strings to structured maps:

```elixir
%{
  text: String.t(),   # human-readable description, e.g. "Alice played Fireball"
  card: map() | nil   # the card struct if this entry involves a card, else nil
}
```

The list continues to be capped at 20 entries and stored in `socket.assigns.action_log` (and mirrored in `game_state.action_log`).

---

## Implementation Plan

### 1. Enrich `log_action/3` for `:play_card` (`combat_controller.ex`)

The `:play_card` intent does not carry the card — it lives in `combat.current_turn.card` at the time of the call. Pass `combat` into `log_action` (or read it from `socket.assigns`) and capture the card:

```elixir
defp log_action(socket, %{type: :play_card}, player) do
  card = get_in(socket.assigns, [:game_state, :combat, :current_turn, :card])
  text = if card, do: "#{player.name} played #{card.name}", else: "#{player.name} played a card"
  update_log(socket, %{text: text, card: card})
end
```

### 2. Wrap all other `log_action` clauses as maps

```elixir
defp log_action(socket, %{type: :skip_turn}, player),
  do: update_log(socket, %{text: "#{player.name} skipped their turn", card: nil})

defp log_action(socket, %{type: :pick_card, card: card}, player),
  do: update_log(socket, %{text: "#{player.name} selected #{card.name}", card: nil})

defp log_action(socket, _, _player), do: socket
```

`update_log/2` requires no change — it already accepts any term.

### 3. Update the HUD timeline (`combat_hud.ex`)

Replace the bare `{action}` interpolation with a helper component that handles both map entries (new) and plain strings (backward compat):

```heex
<li
  :for={{action, index} <- Enum.with_index(@action_log)}
  class="![grid-template-columns:1fr_16px] mr-8 group relative"
>
  <hr :if={index > 0} />
  <div class="timeline-start timeline-box">
    {if is_map(action), do: action.text, else: action}
  </div>
  <!-- Hover card overlay -->
  <div
    :if={is_map(action) && action.card != nil}
    class="absolute left-full top-0 ml-2 z-50 invisible group-hover:visible pointer-events-none"
  >
    <.card card={action.card} disabled={true} />
  </div>
  <div class="timeline-middle min-w-4 min-h-4 rounded-full bg-base-300"></div>
  <hr :if={index < Enum.count(@action_log) - 1} />
</li>
```

`group relative` on the `<li>` and `group-hover:visible` on the overlay are standard Tailwind hover-group patterns — no JS required.

### 4. Backward-compat guard (`game_live.ex`)

No change needed — the action log is already read as-is from `game_state.action_log`. The HUD template already guards with `is_map(action)` above, so stale string entries render as plain text without crashing.

---

## Critical Files

| File | Change |
|------|--------|
| `lib/game_web/live/combat_controller.ex` | `log_action` for `:play_card` reads card from `socket.assigns`; all clauses wrap entries as `%{text, card}` |
| `lib/game_web/live/combat_hud.ex` | Timeline `<li>` renders `action.text`; hover overlay shows `.card` when `action.card != nil` |

---

## TDD Approach

### Unit tests — `combat_controller.ex` behavior

Test `log_action` indirectly through the public event handler. For each action type, assert the head of `socket.assigns.action_log` is the expected map shape:

```elixir
# :skip_turn → card: nil
assert %{text: text, card: nil} = hd(socket.assigns.action_log)
assert text =~ "skipped"

# :play_card with a card in current_turn → card is present
assert %{text: text, card: card} = hd(socket.assigns.action_log)
assert text =~ card.name
```

### Integration test — `sandbox_live_test.exs`

```elixir
test "action log shows card name and renders hover overlay after playing a card" do
  # set up combat, pick a card, play it
  # assert action_log entry text contains the card name
  assert_text_in_element(view, "[data-log-entry]", card.name)
  # assert the hover overlay container is present in the DOM
  assert view |> element(".group .card") |> has_element?()
end
```

### Verification steps

1. Open the sandbox, play any card — confirm the action log reads `"[Player] played [Card Name]"`.
2. Hover that log entry — a full card component appears to the right.
3. Skip a turn — log entry shows skip text; hovering shows nothing extra, no crash.
4. Play 21 cards — confirm log still caps at 20 entries.
5. Reload the page mid-session — confirm no crash if stale string entries are in `game_state.action_log`.
