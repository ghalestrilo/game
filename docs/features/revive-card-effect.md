# Revive Card Effect

## Overview

The `Revive` card effect brings a dead character back into combat with a specified amount of HP. It is the only effect that can target dead characters, and it cannot target alive ones.

## Behavior

1. **Dead-only targeting** — the card can only be cast on characters with `dead: true`. Targeting validation rejects alive targets.
2. **Returns to queue** — the revived character is appended to the end of the turn queue and can act normally on their next turn.
3. **HP on revival** — the character returns with `max(value, 1)` HP (minimum 1 to avoid immediately dying again).
4. **No effect on alive targets** — if a revive effect reaches an alive character (e.g. via AoE), it silently no-ops.

## Constraints

- Revive can only be played while the game is still `:running` (i.e., at least two teams have alive members). In a 2-player 2-team game, killing the last enemy ends the game before revive can be used. Revive is most useful in 3+ character scenarios where teammates can be revived.
- `check_game_over` runs after `process/3`, so the revived character's `dead: false` is already set when alive-team counts are re-evaluated — no risk of a spurious game over.

## Implementation

### `lib/game/combat/card_effects/revive.ex`

- Guard clause no-ops on alive targets: `process(%Revive{}, %{dead: false}, state), do: state`
- Main clause sets `dead: false`, `hp: max(value, 1)`, calls `CombatState.reinsert_into_queue/2`

### `lib/game/card.ex` — `build_target_data/1`

- Adds `"dead"` field to the character branch of the target data map so JsonLogic targeting rules can filter on `target.dead`

### `lib/game_web/live/combat_controller.ex` — `event_to_intent`

- Extends character-ID click resolution to also search `dead_characters`, so clicking a dead character's sprite with a revive card selected works correctly

## Card Definition Example

```elixir
%Game.Card{
  id: 999,
  name: "Revive",
  cost: 2,
  range: 5,
  effects: [%Game.Combat.CardEffects.Revive{value: 5}],
  targeting: %{
    "type" => "character",
    "allow_dead" => true,
    "rule" => %{"==" => [%{"var" => "target.dead"}, true]}
  }
}
```
