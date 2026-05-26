# Feature: Shop Replaced by Booster + Next Combat

## Context

The current shop (`ShopLive`, `Game.enter_shop/1`) is a dead-end card-picker that requires the
campaign flow to manually restart combat via `restart_campaign_combat/2`. It is a separate `:shop`
view with its own `state: :shop` on the `CombatState`.

This feature replaces the shop with a two-phase inter-combat flow:

1. **Booster phase** — player picks one card from a booster pack (same `card_modal` + `pick_booster_card` flow already used in multiplayer).
2. **New combat** — immediately after the booster pack is exhausted, a new combat begins on a
   randomly selected map.

The `:shop` view and `ShopLive` are removed. `enter_shop` is renamed `enter_booster` and transitions
to `:booster` instead of `:shop`. The shop state on `CombatState` is dropped.

---

## Implementation Plan

### 1. Extend `Game.Maps` with a random-map helper

**File:** `lib/game/maps.ex`

Add a function that returns a random map slug from all available maps (builtin + DB):

```elixir
@doc "Returns a random MapTemplate from all known maps (builtin + DB)."
def random do
  db_slugs = Repo.all(from m in Map, select: m.slug)
  all_slugs = Elixir.Map.keys(@builtin_maps) ++ db_slugs
  slug = Enum.random(all_slugs)
  get(slug)
end
```

If no maps exist at all, fall back to `nil` (CombatBuilder already handles `nil` with a dynamic
grid).

### 2. Replace `enter_shop` with `enter_booster` in `Game`

**File:** `lib/game.ex`

Remove `handle_call(:enter_shop, ...)` and `generate_shop_cards/1`.

Add `enter_booster/1` public function and its handler:

```elixir
def enter_booster(game_pid), do: GenServer.call(game_pid, :enter_booster)

def handle_call(:enter_booster, _from, state) do
  if state.combat.state == :game_over do
    booster_size  = get_in(state, [:settings, :booster_size])  || 5
    deck_picks    = get_in(state, [:settings, :deck_picks])     || 1
    players       = state.combat.__constants__.players

    booster_state =
      Elixir.Map.new(players, fn p ->
        {p.id, %{remaining: 1, picks_remaining: deck_picks, cards: generate_booster_cards(booster_size)}}
      end)

    new_state = %{state | booster_state: booster_state, current_view: :booster}
    broadcast(self(), new_state)
    {:reply, {:ok, new_state}, new_state}
  else
    {:reply, {:error, "Can only enter booster after combat is over"}, state}
  end
end
```

The existing `pick_booster_card` handler already transitions to `:combat` once all players are done.
The only change needed there is to use `Maps.random()` for the new combat's map:

```elixir
# In handle_call({:pick_booster_card, ...}, ...) — where all_done == true:
{:combat, Game.CombatBuilder.build(specs, map: Game.Maps.random(), settings: state[:settings])}
```

Remove the `generate_shop_cards/1` private function.

### 3. Update `GameLive` — replace shop event with booster entry

**File:** `lib/game_web/live/game_live.ex`

Replace the `"enter_shop"` event handler with `"enter_booster"`:

```elixir
def handle_event("enter_booster", _params, socket) do
  if socket.assigns.game_state.combat.state == :game_over do
    case Game.enter_booster(socket.assigns.game_pid) do
      {:ok, new_state} ->
        {:noreply, assign(socket, game_state: new_state, modal: nil)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not enter booster: #{reason}")}
    end
  else
    {:noreply, put_flash(socket, :error, "Combat must be over to open booster")}
  end
end
```

Remove the `"select_shop_card"` event handler and `restart_campaign_combat/2` private helper
(combat restart is now handled inside `Game.pick_booster_card`).

Update the game-over button in the template (wherever `phx-click="enter_shop"` appears) to
`phx-click="enter_booster"`.

Remove the `:shop` view branch from the render:

```heex
<%# Remove this: %>
<%= if @game_state && Map.get(@game_state, :current_view) == :shop do %>
  <.live_component module={GameWeb.ShopLive} id="shop" game_state={@game_state} />
<% end %>
```

The `:booster` branch is already present and handles the new flow without changes.

### 4. Delete `ShopLive`

**File:** `lib/game_web/live/shop_live.ex`

Delete the file. The shop view is fully replaced by the booster card_modal.

### 5. Remove shop state from `CombatState`

**File:** `lib/game/combat_state.ex` (or wherever `shop_cards` is defined)

Remove the `shop_cards` field from the struct and any code that sets it. The `CombatBuilder` already
initialises it to `[]` — remove that line too.

---

## TDD Plan

Write failing tests first, then implement.

### Test file: `test/game_test.exs`

Add a new `describe` block:

```elixir
describe "enter_booster/1" do
  test "transitions current_view to :booster after game_over"
  test "returns error if combat is not game_over"
  test "initialises booster_state for every player in __constants__.players"
  test "each player's booster pack has the configured booster_size number of cards"
end
```

### Test file: `test/game/maps_test.exs` (new file)

```elixir
describe "Maps.random/0" do
  test "returns a MapTemplate"
  test "returns different maps across multiple calls (statistical — run 20 times, expect > 1 unique)"
  test "falls back gracefully when no DB maps exist (returns a builtin)"
end
```

### Test file: `test/game_test.exs` — extend `pick_booster_card` tests

```elixir
describe "pick_booster_card — random map on next combat" do
  test "when all players finish their pack, new combat grid matches a known map template's tile count"
  test "new combat state is :running after booster completion"
  test "current_view is :combat after booster completion"
end
```

### Test file: `test/game_web/live/game_live_test.exs` (new or extend existing)

```elixir
describe "enter_booster event" do
  test "returns error flash when combat is not game_over"
  test "assigns booster game_state when combat is game_over"
  test "enter_shop event no longer exists (returns error or is unhandled)"
end
```

---

## Critical Files

| File | Change |
|------|--------|
| `lib/game/maps.ex` | Add `random/0` |
| `lib/game.ex` | Replace `enter_shop`/`generate_shop_cards` with `enter_booster`; pass `Maps.random()` to `CombatBuilder` when booster completes |
| `lib/game_web/live/game_live.ex` | Replace `"enter_shop"` + `"select_shop_card"` events with `"enter_booster"`; remove `:shop` render branch; remove `restart_campaign_combat/2` |
| `lib/game_web/live/shop_live.ex` | **Delete** |
| `lib/game/combat_state.ex` | Remove `shop_cards` field |
| `test/game_test.exs` | New `describe` for `enter_booster` and booster→combat transition |
| `test/game/maps_test.exs` | New file — `Maps.random/0` tests |
| `test/game_web/live/game_live_test.exs` | Add `"enter_booster"` event tests |

---

## Verification

1. Win a combat — confirm a booster pack appears (not a shop) showing 5 cards.
2. Pick a card — confirm it is added to the deck.
3. After picking, confirm a new combat immediately starts on a (potentially different) map.
4. Run the flow several times — confirm the map varies across sessions.
5. Confirm `/shop` route and `ShopLive` are fully gone (no dead routes or render branches).
6. Confirm `CombatState` no longer carries `shop_cards`.
