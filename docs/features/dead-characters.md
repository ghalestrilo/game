# Feature: Dead Characters

## Context

Currently when a character's HP drops to 0, `CombatState.check_target_death/2` sets `dead: true` on
the struct, and `check_game_over/1` filters dead characters out of the turn queue and alive-team
count. The `dead` flag and `Character.is_dead?/1` already exist — the infrastructure is mostly in
place.

What's missing:

- Dead characters are removed from the `CharacterLayer` in the 3D board (because `build_characters`
  only sends living characters, so `CharacterLayer.sync` removes anyone not in the list).
- There is no death animation — the character simply disappears.
- No targeting guard: card effects (damage, heal, stun, etc.) can reach `dead: true` targets because
  nothing filters them out at the targeting or effect-processing layer.
- There is no `revive` card effect.
- Turn queue logic skips dead characters correctly already (they're removed from `queue` in
  `check_game_over`), but a dead character that gets revived would need re-inserting.

---

## Implementation Plan

### 1. Keep dead characters on the board

**File:** `lib/game_web/live/game_board_3d.ex`

In `build_characters/2`, remove the implicit alive-only filter: currently `get_current_queue` returns
only the queue (which has dead characters stripped in `check_game_over`). We need to also pass dead
characters to the frontend so they remain visible.

**Approach:** Store dead characters in `CombatState` in a separate `dead_characters` list field
instead of discarding them. Update `check_game_over/1` to move dead characters there rather than
drop them.

```elixir
# In CombatState defstruct, add:
dead_characters: []
```

In `check_game_over/1`:
```elixir
newly_dead = Enum.filter(combat.queue, &(&1.dead == true))
dead_characters = (combat.dead_characters ++ newly_dead) |> Enum.uniq_by(& &1.id)
alive_queue = Enum.filter(combat.queue, &(&1.dead == false))
```

Then in `build_characters/2`, include both alive and dead characters but tag dead ones:
```elixir
all_characters = Game.CombatState.get_current_queue(combat) ++ combat.dead_characters
```

Pass a `dead: true/false` field in the character map to the frontend.

**File:** `assets/js/board/character-layer.js`

Extend `CharacterLayer.sync` to support a `dead` flag:
- If `dead: true`, play the `death` animation clip instead of idle and do not restart idle on
  subsequent `sync` calls if already dead.
- The node stays in `this._map` so hit effects and floats still work.

```js
// In sync():
if (c.dead && !entry.dead) {
  entry.dead = true
  entry.deathAction = mixer.clipAction(this._assets.clips.death)
  entry.deathAction.setLoop(THREE.LoopOnce)
  entry.deathAction.clampWhenFinished = true
  entry.deathAction.reset().play()
  entry.deathAction.crossFadeFrom(entry.idleAction, 0.2, true)
}
```

A `death` animation clip must be added to `default_assets` in `game_board_3d.ex` (alongside `idle`
and `walk`). If the asset is unavailable, fall back to playing the idle clip at 0.3 speed and
desaturating the material.

### 2. Death animation (fallback if no clip)

**File:** `assets/js/board/character-layer.js`

If no death clip is loaded, apply a greyscale material filter on the character's meshes when
`dead: true` arrives:

```js
node.traverse(o => {
  if (!o.isMesh && !o.isSkinnedMesh) return
  o.material = o.material.clone()
  o.material.color.multiplyScalar(0.4)
  o.material.emissive.set(0x000000)
})
```

This is a visual fallback until a proper death clip is available.

### 3. Block card effects on dead characters (except revive)

**File:** `lib/game/card.ex` — `is_target_cell_valid?/3` and `is_target_valid_for_character?/3`

Both targeting validators return `{:ok, character}` for any character found at a position. Add a
dead-character guard:

```elixir
# After resolving the character from the grid/queue:
case character do
  %{dead: true} -> {:error, "Cannot target a dead character"}
  _ -> {:ok, character}
end
```

Cards that should be able to target dead characters (i.e. revive) can opt out via their `targeting`
map with `"allow_dead": true`:

```elixir
case targeting do
  %{"allow_dead" => true} -> {:ok, character}
  _ when character.dead -> {:error, "Cannot target a dead character"}
  _ -> {:ok, character}
end
```

**File:** `lib/game/card.ex` — `apply_card_effects/4`

As a second line of defense, skip effect processing when the resolved target is dead (unless the
effect is `:revive`):

```elixir
if current_target.dead && resolved.type != :revive do
  {combat_state, anims}
else
  # existing processing
end
```

### 4. Implement the `revive` card effect

**New file:** `lib/game/combat/card_effects/revive.ex`

```elixir
defmodule Game.Combat.CardEffects.Revive do
  defstruct type: :revive, value: 0, value_label: nil

  defimpl Game.Combat.CardEffect do
    def process(%{value: hp}, target, combat_state) do
      revived = %{target | dead: false, hp: max(hp, 1)}
      # Re-insert into queue after current turn
      combat_state
      |> CombatState.update_target(target, revived)
      |> CombatState.reinsert_into_queue(revived)
    end

    def animate(%{value: v}), do: %{label: "REVIVED +#{v}", color: :green}
    def get_description(%{value: v}), do: "Revive target with #{v} HP"
    def get_icon(_), do: "hero-arrow-up-circle"
    def get_value_label(%{value_label: l}) when is_binary(l), do: l
    def get_value_label(%{value: v}), do: "#{v}"
    def params(_), do: ["value"]
  end
end
```

Register it in `Card.@effect_types`:
```elixir
"revive" => CardEffects.Revive
```

**File:** `lib/game/combat_state.ex` — add `reinsert_into_queue/2`

When a character is revived, they need to re-enter the turn queue. Insert them after the last
character of their original team in the queue, or at the end:

```elixir
def reinsert_into_queue(%CombatState{queue: queue} = combat, character) do
  if Enum.any?(queue, &(&1.id == character.id)) do
    combat
  else
    %{combat | queue: queue ++ [character]}
  end
end
```

Also remove them from `dead_characters`:
```elixir
updated_dead = Enum.reject(combat.dead_characters, &(&1.id == character.id))
%{combat | dead_characters: updated_dead, queue: queue ++ [character]}
```

### 5. Game-over check still works

`check_game_over/1` already filters by `dead == false` to determine surviving teams. Since dead
characters are now stored in `dead_characters` (not in the queue), the existing alive-team logic
requires no changes. Revived characters are moved back to `queue`, so they naturally count as alive
again.

---

## Critical Files

| File | Change |
|------|--------|
| `lib/game/combat_state.ex` | Add `dead_characters: []` field; update `check_game_over/1` to populate it; add `reinsert_into_queue/2` |
| `lib/game/card.ex` | Guard dead targets in targeting validators; skip effects on dead targets except `:revive`; register `"revive"` effect type |
| `lib/game/combat/card_effects/revive.ex` | New file — implements the `revive` effect |
| `lib/game_web/live/game_board_3d.ex` | Include `dead_characters` in `build_characters/2`; pass `dead:` field; add `death` animation to `default_assets` |
| `assets/js/board/character-layer.js` | Handle `dead: true` in `sync()`: play death animation or apply greyscale fallback; keep node in map |

---

## Verification

1. Start a combat with 2 teams.
2. Kill a character — confirm they remain visible on the board with a death animation (or greyscale
   tint) and do not disappear.
3. Select a damage card and attempt to target the dead character — confirm it is blocked (no valid
   target highlight, error in UI if applicable).
4. Add a card with `"revive"` effect to a player's hand (via sandbox or seeding).
5. Use revive on the dead character — confirm they reappear as alive (normal animation restored),
   re-enter the turn queue, and can act on their next turn.
6. Kill all characters on one team — confirm game-over modal still triggers correctly and revived
   characters on the surviving team appear in the "Surviving Characters" list.
