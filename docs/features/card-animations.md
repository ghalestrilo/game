# Card Animations

## Context

Cards currently have no animation data. Each card should declare which character animation clip to play when it is **selected** from hand and when it is **played**. The 3D board already loads named animation clips (`idle`, `walk`, `death`) and crossfades between them via Three.js AnimationMixer; we wire card-level animation triggers into that existing system.

Animation values are asset _keys_ (e.g. `"idle"`, `"walk"`) — the JS `AssetLoader` maps them to Three.js `AnimationClip` objects stored in `this.clips[key]`. Default is `"idle"` for both triggers.

---

## Implementation (TDD, layer by layer)

### Layer 1 — `Game.Card` struct

**File:** `lib/game/card.ex`

Add `:animations` to `defstruct` with struct-level default:

```elixir
animations: %{selected: "idle", played: "idle"}
```

Add a public `coerce_animations/1` function:
- `nil` / missing → `%{selected: "idle", played: "idle"}`
- atom-key or string-key map → atomise keys, fill any `nil` value with `"idle"`
- partial map (only one key) → fill the missing key with `"idle"`

**Tests first** (`test/game/card_test.exs`, new `describe "animations field"`):
```
test "struct default is %{selected: "idle", played: "idle"}"
test "coerce_animations/1: nil → defaults"
test "coerce_animations/1: empty map → defaults"
test "coerce_animations/1: partial map fills missing key"
test "coerce_animations/1: string-key map is atomised"
test "coerce_animations/1: valid atom-key map passes through"
test "coerce_animations/1: nil values inside map replaced with idle"
```

---

### Layer 2 — Card construction pipeline

Two places build `%Game.Card{}` from `%BaseCard{}` and must call `coerce_animations/1`.

**File 1:** `lib/game/base_decks/base_deck.ex` — `base_card_to_card/1`

```elixir
|> Map.merge(%{cost: card.ap, animations: Game.Card.coerce_animations(card.animations)})
```

**File 2:** `lib/game.ex` — `base_card_to_game_card/2`

```elixir
|> Map.merge(%{cost: base_card.ap, id: id, animations: Game.Card.coerce_animations(base_card.animations)})
```

**Tests first** (pure in-memory, `test/game/card_test.exs`):
```
test "base_card_to_card: animations field is present with defaults when base_card has nil animations"
```

---

### Layer 3 — DB migration + `BaseCard` schema

**Migration** (`priv/repo/migrations/<timestamp>_add_animations_to_cards.exs`):
```elixir
def change do
  alter table(:cards) do
    add :animations, :map  # nullable; existing rows load as nil → coerced to defaults at runtime
  end
end
```

**Schema** (`lib/game/base_cards/base_card.ex`):
- Add `field :animations, :map` inside `schema "cards"`
- Add `:animations` to `cast/2` in `changeset/2` (no `validate_required` — nullable)

**Tests first** (`test/game/base_cards_test.exs`):
```
test "create_base_card/1 with animations map persists and retrieves it"
test "create_base_card/1 without animations has nil in DB"
test "update_base_card/2 can set animations"
```

---

### Layer 4 — LiveView push events

Two push_event moments for the `"card_animation"` event:

**A) Card selected** — after `pick_card` succeeds and state transitions to `:card_selected`.

Hook into `handle_info({:game_updated, ...}, socket)` in `lib/game_web/live/game_live.ex`:

```elixir
|> push_card_animation(game_state)
```

Add `push_card_animation/2` to `lib/game_web/live/combat_action_helpers.ex`:

```elixir
def push_card_animation(socket, %{combat: %{state: :card_selected, current_turn: %{card: card, player: player}}})
    when not is_nil(card) do
  clip = Map.get(card.animations || %{}, :selected, "idle")
  Phoenix.LiveView.push_event(socket, "card_animation", %{trigger: "selected", animation: clip, caster_id: player.id})
end
def push_card_animation(socket, _), do: socket
```

**B) Card played** — prepend a sentinel entry to the animations list in `Card.process_card/3` (`lib/game/card.ex`):

```elixir
caster = CombatState.get_current_player(combat_state)
card_anim = %{type: :card_animation, trigger: "played", animation: Map.get(card.animations || %{}, :played, "idle"), caster_id: caster.id}
{combat, [card_anim | anims]}
```

Update `push_animations/2` in `lib/game_web/live/combat_action_helpers.ex` to handle the new entry shape:

```elixir
def push_animations(socket, animations) do
  Enum.reduce(animations, socket, fn
    %{type: :card_animation, trigger: trigger, animation: clip, caster_id: id}, s ->
      Phoenix.LiveView.push_event(s, "card_animation", %{trigger: trigger, animation: clip, caster_id: id})
    %{target_id: target_id} = anim, s ->
      color = Map.get(anim, :color, :yellow)
      label = Map.get(anim, :label, "")
      s
      |> Phoenix.LiveView.push_event("hit", %{id: target_id, color: color})
      |> Phoenix.LiveView.push_event("float", %{id: target_id, label: label, color: color})
  end)
end
```

Note: `tagged_animations` in `lib/game.ex` adds `target_id` via `Map.put`. The `:card_animation` entries have `caster_id` but no `target_id`; the spurious key added by `Map.put` does not affect pattern matching.

**Tests first** (`test/game_web/live/card_animation_test.exs`):
```
test "selecting a card pushes card_animation with trigger: selected and the card's animation clip"
test "playing a card pushes card_animation with trigger: played"
test "card with nil animations pushes idle for both triggers"
```
Use `assert_push_event/3` from `Phoenix.LiveViewTest`.

---

### Layer 5 — JS (`ThreeJSBoard.js` + `character-layer.js`)

**`assets/js/hooks/ThreeJSBoard.js`** — add in `mounted()` after existing event handlers:

```js
this.handleEvent("card_animation", ({ trigger, animation, caster_id }) => {
  this._charLayer.playCastAnimation(Number(caster_id), animation)
})
```

**`assets/js/board/character-layer.js`** — add `playCastAnimation(casterId, clipKey)`:

```js
playCastAnimation(casterId, clipKey) {
  const entry = this._characters.get(casterId)
  if (!entry) return
  const clip = this._assets.clips[clipKey] ?? this._assets.clips.idle
  if (!clip) return

  const castAction = entry.mixer.clipAction(clip)
  castAction.setLoop(THREE.LoopOnce)
  castAction.clampWhenFinished = false
  castAction.reset().play()
  castAction.crossFadeFrom(entry.idleAction, 0.15, true)  // crossFadeFrom on destination (CLAUDE.md)

  const duration = (clip.duration * 1000) || 600
  setTimeout(() => {
    entry.idleAction.reset().play()
    entry.idleAction.crossFadeFrom(castAction, 0.2, true)
  }, duration)
}
```

Falls back to `idle` clip if the key is unknown. Since default card animations are `"idle"`, this is a visual no-op until real cast clips (e.g. `"cast"`) are added to `default_assets/0` in `game_board_3d.ex`.

---

## Critical files

| File | Change |
|------|--------|
| `lib/game/card.ex` | Add `:animations` field + `coerce_animations/1` |
| `lib/game/base_decks/base_deck.ex` | Call `coerce_animations/1` in `base_card_to_card/1` |
| `lib/game.ex` | Call `coerce_animations/1` in `base_card_to_game_card/2` |
| `lib/game/base_cards/base_card.ex` | Add `field :animations, :map` + cast |
| `priv/repo/migrations/<ts>_add_animations_to_cards.exs` | New migration |
| `lib/game_web/live/combat_action_helpers.ex` | Add `push_card_animation/2`; update `push_animations/2` |
| `lib/game_web/live/game_live.ex` | Call `push_card_animation/2` in `handle_info` |
| `assets/js/hooks/ThreeJSBoard.js` | Handle `"card_animation"` event |
| `assets/js/board/character-layer.js` | Add `playCastAnimation` method |
| `test/game/card_test.exs` | Struct + coercion tests |
| `test/game/base_cards_test.exs` | DB schema tests |
| `test/game_web/live/card_animation_test.exs` | LiveView push event tests (new file) |

---

## Verification

```bash
mix test test/game/card_test.exs
mix test test/game/base_cards_test.exs
mix test test/game_web/live/card_animation_test.exs
mix test  # full suite, no regressions
```

Smoke test: open sandbox, select a card and confirm a `card_animation` event with `trigger: "selected"` fires in the browser console; play the card and confirm `trigger: "played"`. With default `"idle"` clip no visible change occurs. To verify the crossfade, set a card's `:selected` animation to `"walk"` in seeds and observe the character briefly walk on card selection.
