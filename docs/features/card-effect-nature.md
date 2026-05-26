# Card Effect Nature Callback

## Goal

Add a `nature/1` callback to the `Game.Combat.CardEffect` protocol that classifies each effect as `:buff`, `:debuff`, or `:neutral`. This enables downstream rules (e.g. cleanse targeting, buff-counting mechanics) and HUD improvements (color-coding, iconography) to query effect nature without inspecting effect types directly.

## Protocol Change

Add to `lib/game/combat/card_effect.ex`:

```elixir
@doc """
Returns the nature of this effect. Used for targeting rules and HUD display.
"""
@spec nature(t()) :: :buff | :debuff | :neutral
def nature(card_effect)
```

## Implementation Per Effect

| Effect           | Nature     | Rationale                                              |
|------------------|------------|--------------------------------------------------------|
| `Heal`           | `:buff`    | Restores HP                                            |
| `Shield`         | `:buff`    | Grants protection                                      |
| `Regen`          | `:buff`    | Heals over time                                        |
| `Ethereal`       | `:buff`    | Grants untargetability                                 |
| `Stealth`        | `:buff`    | Hides the character                                    |
| `Revive`         | `:buff`    | Brings character back from death                       |
| `Give`           | `:buff`    | Provides a card resource                               |
| `Draw`           | `:buff`    | Draws cards (self-targeting)                           |
| `ModifyAttribute`| dynamic    | `:buff` if `value >= 0`, `:debuff` if `value < 0`     |
| `Damage`         | `:debuff`  | Deals direct damage                                    |
| `Dot`            | `:debuff`  | Deals damage over time                                 |
| `Stun`           | `:debuff`  | Removes target's turn                                  |
| `Slow`           | `:debuff`  | Reduces movement                                       |
| `Stuck`          | `:debuff`  | Prevents movement                                      |
| `Hex`            | `:debuff`  | Inverts healing/damage                                 |
| `Discard`        | `:debuff`  | Removes cards from target's hand                       |
| `Cleanse`        | `:neutral` | Removes debuffs — effect on caster is situational      |
| `Move`           | `:neutral` | Positional; context-dependent (escape vs. forced move) |
| `SelfDestruct`   | `:neutral` | Card removal; neither buff nor debuff on a character   |
| `Summon`         | `:neutral` | Creates a new unit; doesn't affect existing characters |

`Cleanse` could be argued as `:buff` but is kept `:neutral` here because it is an enabler effect — rules that react to "buff applied" should not trigger on cleanse.

## HUD Applications

- Effect badges on character portraits can use `nature/1` to pick a border color without per-type logic: green for `:buff`, red/orange for `:debuff`, grey for `:neutral`.
- Cards in hand could display a nature indicator (small colored pip or icon tint) so players can quickly distinguish buff/debuff cards.
- Tooltip headers can prepend "Buff:" / "Debuff:" / "" based on nature.

## Rule Applications (future)

- **Cleanse targeting**: `cleanse` removes all active effects where `nature(effect) == :debuff`.
- **Buff-count mechanic**: a card or passive that scales with "number of active buffs on target" can use `nature/1` instead of an allowlist.
- **Hex inversion**: `hex` could invert effects whose nature is `:buff` → apply as `:debuff` and vice versa.

## Implementation Steps

1. Add `nature/1` to the protocol in `card_effect.ex`.
2. Implement `def nature(_), do: :neutral` as the default `Any` fallback (if protocol consolidation is used), or implement explicitly in each module.
3. Add `@impl Game.Combat.CardEffect` annotation above each `nature/1` clause.
4. For `ModifyAttribute`, match on `value >= 0` vs negative (mirroring the existing `animate/1` logic).
5. Update any HUD LiveView or component that renders effect badges to call `CardEffect.nature(effect)` and apply the appropriate CSS class or color atom.

## Notes

- No changes to `process/3`, `animate/1`, or any existing callbacks.
- `nature/1` is pure / side-effect-free — safe to call during rendering.
- New effects added in the future should default to `:neutral` if unsure; authors should opt-in to `:buff`/`:debuff` consciously.
