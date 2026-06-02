# Feature: Aura Effects

## Context

Cards and status effects currently apply once at cast time. An **aura** is a persistent zone that
emanates from a character's position and continuously applies an effect to all characters within N
tiles — including the caster themselves. As the caster moves, the aura re-centres.

Auras sit at the intersection of three existing systems:
- **Card effects** — a card casts an aura onto the caster
- **Status effects** — the aura is stored on the caster as a status effect map
- **Movement** — after every move, aura effects are recalculated for everyone in range

Auras are _not_ AoE (which fires once at a target tile). They are persistent and positional.

---

## Design Decisions

**Auras live on the caster as a status effect** with `type: :aura`. This is consistent with how
all other persistent effects (dot, regen, shield, stun…) are stored: as maps in
`character.status_effects`. The aura map carries its own inner `effect` (any existing card effect
struct), a `radius`, a `duration` in turns, and a `targeting` atom (`:allies`, `:enemies`, `:all`,
`:self_only`) that determines which characters in range are affected.

**Application is declarative, not mutative.** At each point where auras need to resolve — after
a move, at start of turn — the combat state is scanned for all characters that carry `:aura` status
effects, and their effects are applied fresh to all characters currently in range. Auras that deal
damage or healing do so once per triggering event (move or turn start), controlled by the
`trigger` field (`:on_turn_start`, `:on_move`, or `:always` meaning both).

**Aura removal:** when an aura expires (duration reaches 0 at start of turn, same tick path as all
other status effects) its in-range effects stop automatically — no cleanup pass needed.

---

## Data Shape

An aura status effect stored on a character:

```elixir
%{
  type: :aura,
  radius: 2,
  duration: 3,           # turns remaining; -1 = permanent until dispelled
  trigger: :on_turn_start,  # :on_turn_start | :on_move | :always
  targeting: :enemies,   # :allies | :enemies | :all | :self_only
  effect: %Game.Combat.CardEffects.Damage{value: 5},  # any CardEffect struct
  source_id: 42          # caster's character id — for multi-aura dedup / display
}
```

The `effect` field holds a real card-effect struct (not a raw map) so the existing
`CardEffect.process/3` protocol implementation is called directly — no new effect-processing code.

---

## Implementation Plan

### 1. Add `:aura` as a known status effect kind

**File:** `lib/game/combat/status_effect.ex`

```elixir
def kind(:aura), do: :buff
```

Add `:aura` to the tick/decrement block (duration decremented once per turn like all others):

```elixir
%{type: :aura, duration: d} = e when d > 0 -> %{e | duration: d - 1}
```

Reject when `duration == 0` (and `duration != -1`):

```elixir
%{type: :aura, duration: 0} -> true
```

### 2. Add an `Aura` card effect that installs the aura onto the caster

**New file:** `lib/game/combat/card_effects/aura.ex`

```elixir
defmodule Game.Combat.CardEffects.Aura do
  defstruct type: :aura,
            radius: 1,
            duration: 3,
            trigger: :on_turn_start,
            targeting: :enemies,
            effect: nil,   # inner CardEffect struct
            value_label: nil

  defimpl Game.Combat.CardEffect do
    alias Game.{Character, CombatState}

    def process(%Aura{} = aura, target, %CombatState{} = combat_state) do
      status = %{
        type: :aura,
        radius: aura.radius,
        duration: aura.duration,
        trigger: aura.trigger,
        targeting: aura.targeting,
        effect: aura.effect,
        source_id: target.id
      }
      updated = Character.add_status_effect(target, status)
      CombatState.update_target(combat_state, target, updated)
    end

    def get_description(%Aura{radius: r, duration: d, targeting: t}),
      do: "Emit an aura (radius #{r}, #{d} turns) affecting #{t}"

    def get_icon(_), do: "hero-signal"
    def get_value_label(%Aura{value_label: v}), do: v
    def animate(_), do: %{label: "AURA", color: :blue}
    def params(_), do: ["radius", "duration", "trigger", "targeting", "effect"]
  end
end
```

### 3. Add `apply_auras/1` to `CombatState`

**File:** `lib/game/combat_state.ex`

This function iterates every character in the queue + current_turn player, finds their `:aura`
status effects, and applies each aura's inner effect to all in-range characters that match the
targeting rule.

```elixir
def apply_auras(%__MODULE__{} = combat, trigger_filter \\ :all) do
  all_chars = get_current_queue(combat)

  Enum.reduce(all_chars, combat, fn caster, acc ->
    auras =
      caster.status_effects
      |> Enum.filter(&(&1.type == :aura))
      |> Enum.filter(fn a ->
        trigger_filter == :all or a.trigger == trigger_filter or a.trigger == :always
      end)

    Enum.reduce(auras, acc, fn aura, cs ->
      apply_single_aura(cs, caster, aura)
    end)
  end)
end

defp apply_single_aura(combat, caster, aura) do
  in_range =
    Game.Grid.tiles_in_range(combat.grid, caster.position, aura.radius)
    |> Enum.flat_map(fn pos ->
      case Game.Grid.get_object(combat.grid, pos) do
        {:ok, %Game.Character{} = char} -> [char]
        _ -> []
      end
    end)
    |> Enum.filter(&aura_targets?(&1, caster, aura.targeting))
    |> Enum.reject(& &1.dead)

  Enum.reduce(in_range, combat, fn target, cs ->
    fresh = refresh_target(target, cs)
    Game.Combat.CardEffect.process(aura.effect, fresh, cs)
  end)
end

defp aura_targets?(char, caster, :self_only), do: char.id == caster.id
defp aura_targets?(char, caster, :allies),    do: char.team == caster.team
defp aura_targets?(char, caster, :enemies),   do: char.team != caster.team and not char.dead
defp aura_targets?(_char, _caster, :all),     do: true
```

Add a private `refresh_target/2` delegation (same pattern already in `card.ex`):
```elixir
defp refresh_target(target, combat) do
  get_current_queue(combat) |> Enum.find(target, &(&1.id == target.id))
end
```

### 4. Hook `apply_auras` into movement

**File:** `lib/game/combat.ex` — `process_action/2` for `{:move, ...}`

Insert one call after `apply_entry_effects`:

```elixir
updated_combat = apply_entry_effects(updated_combat, player, target_position)
updated_combat = CombatState.apply_auras(updated_combat, :on_move)  # <-- new
result = CombatState.update_players_and_queue(updated_combat)
```

### 5. Hook `apply_auras` into turn start

**File:** `lib/game/combat_state.ex` — `setup_player_turn/1`

Insert after `tick_status_effects/1`:

```elixir
after_tick =
  combat
  |> put_in([:state], :running)
  |> put_in([:current_turn], new_turn(next_player))
  |> tick_status_effects()
  |> apply_auras(:on_turn_start)  # <-- new
```

### 6. Extend `get_structured_effect/1` in `Card` to deserialize the Aura struct

**File:** `lib/game/card.ex` — wherever card effects are deserialized from raw maps

Add a clause for `"aura"` type that also recursively deserializes the inner `"effect"`:

```elixir
defp get_structured_effect(%{"type" => "aura"} = raw) do
  inner = get_structured_effect(raw["effect"] || %{})
  %Game.Combat.CardEffects.Aura{
    radius:    raw["radius"]    || 1,
    duration:  raw["duration"]  || 3,
    trigger:   String.to_existing_atom(raw["trigger"]   || "on_turn_start"),
    targeting: String.to_existing_atom(raw["targeting"] || "enemies"),
    effect:    inner
  }
end
```

### 7. Admin UI — aura effect field

**File:** `lib/game_web/live/admin/fields/effect_field.ex` (or wherever effect types are listed)

Add `"aura"` to the type select. The aura fields (radius, duration, trigger, targeting, nested
effect) should render a sub-form that reuses the existing effect field component recursively for
the inner effect — identical to how nested effects work elsewhere.

---

## Visual Indicator (optional but recommended)

Auras should be visible on the hex grid so players know what they are standing in. After any move
or turn-start, the LiveView can derive aura-covered tiles from the game state and apply a CSS class
to those hex cells.

In `CombatState`, add a pure helper (no state mutation):

```elixir
def aura_tiles(%__MODULE__{} = combat) do
  get_current_queue(combat)
  |> Enum.flat_map(fn char ->
    char.status_effects
    |> Enum.filter(&(&1.type == :aura))
    |> Enum.flat_map(fn aura ->
      Game.Grid.tiles_in_range(combat.grid, char.position, aura.radius)
      |> Enum.map(&{&1, aura.targeting, char.id})
    end)
  end)
end
```

Pass `aura_tiles` to the hex grid component as an assign; render a translucent overlay class on
matching tiles.

---

## TDD Plan

### `test/game/combat/card_effects/aura_test.exs` (new)

```elixir
describe "Aura card effect — process/3" do
  test "installs :aura status effect on target"
  test "aura status effect carries radius, duration, targeting, inner effect, source_id"
  test "stacks with other auras (character can have multiple :aura effects)"
end
```

### `test/game/combat_state_test.exs` — add describe block

```elixir
describe "apply_auras/2" do
  test "applies inner effect to enemies in range when targeting: :enemies"
  test "does not apply inner effect to allies when targeting: :enemies"
  test "applies inner effect to all in range when targeting: :all"
  test "applies inner effect only to self when targeting: :self_only"
  test "does not apply to dead characters"
  test "respects radius — characters beyond radius are unaffected"
  test "filters by trigger — :on_turn_start aura skipped when trigger_filter is :on_move"
  test "re-centres on caster's current position after move"
  test "multiple casters each apply their own aura independently"
end

describe "aura expiry via tick_status_effects/1" do
  test "aura with duration 1 is removed after one tick"
  test "aura with duration -1 is never removed"
  test "aura with duration 3 decrements to 2 on tick"
end
```

### `test/game/combat_test.exs` — add to movement tests

```elixir
describe ":on_move auras re-apply after move" do
  test "enemy entering aura range takes damage on the move"
  test "ally moving within aura range receives buff on the move"
  test "caster moving out of enemy's aura range stops taking damage next move"
end
```

### `test/game/card_test.exs` — deserialization

```elixir
describe "get_structured_effect for aura type" do
  test "deserializes top-level aura fields correctly"
  test "deserializes nested inner effect struct"
  test "defaults radius to 1, duration to 3, trigger to :on_turn_start, targeting to :enemies"
end
```

---

## Critical Files

| File | Change |
|------|--------|
| `lib/game/combat/status_effect.ex` | Add `kind(:aura)`, tick/decrement/expiry for `:aura` |
| `lib/game/combat/card_effects/aura.ex` | **New** — `Aura` struct + `CardEffect` protocol impl |
| `lib/game/combat_state.ex` | Add `apply_auras/2`, `aura_tiles/1`; hook `apply_auras` into `setup_player_turn` |
| `lib/game/combat.ex` | Hook `apply_auras(:on_move)` after `apply_entry_effects` in move action |
| `lib/game/card.ex` | Add `get_structured_effect` clause for `"aura"` type with recursive inner effect |
| `lib/game_web/live/admin/fields/effect_field.ex` | Add `"aura"` type + sub-form for aura fields |
| `test/game/combat/card_effects/aura_test.exs` | **New** |
| `test/game/combat_state_test.exs` | New `describe` blocks for `apply_auras` and expiry |
| `test/game/combat_test.exs` | New move + aura integration tests |
| `test/game/card_test.exs` | Deserialization tests for `"aura"` effect type |

---

## Verification

1. Create a card with an `aura` effect (radius 2, duration 3, targeting `:enemies`, inner effect
   `damage value: 5`).
2. Cast it on the caster — confirm `:aura` appears in their status effects.
3. End the turn — confirm all enemies within 2 tiles take 5 damage at turn start.
4. Move the caster toward a previously out-of-range enemy — confirm they now take damage on the
   next trigger.
5. Move an enemy out of range — confirm they stop taking damage.
6. After 3 turns, confirm the aura disappears from status effects and no more damage is dealt.
7. Create an ally aura (targeting `:allies`, inner effect `regen`) — confirm only teammates heal.
8. Create a permanent aura (duration `-1`) — confirm it never expires.
