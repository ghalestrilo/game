# Feature: Card Mechanic — Number of Cards Played This Turn

## Context

Card effect values can be computed via JsonLogic formulas (see `build_effect_context/3` in
`lib/game/card.ex:300`). The formula context already exposes `caster`, `target`, `state`,
directional deltas, and distances. This feature adds `"cards_played_this_turn"` to that context so
card designers can write scaling effects like "deal damage equal to cards played this turn × 3".

---

## Implementation Plan

### 1. Track `cards_played` on `current_turn`

**File:** `lib/game/combat_state.ex`

Add `cards_played: 0` to the `new_turn/1` map:

```elixir
def new_turn(%Character{position: position} = player) do
  %{
    starting_position: position,
    movement_remaining: nil,
    player: player,
    card: nil,
    cards_played: 0
  }
end
```

This resets to 0 at the start of every turn automatically (since `new_turn` is called by
`setup_player_turn` and `rotate_queue`).

### 2. Increment on card play

**File:** `lib/game/card.ex` — `process_card/3` (line 126)

After the card is discarded and AP is spent, increment the counter:

```elixir
def process_card(combat_state, target, card) do
  current_player = CombatState.get_current_player(combat_state)

  updated_combat =
    combat_state
    |> CombatState.update_target(
      current_player,
      current_player
      |> Game.Character.discard_card(card)
      |> Game.Character.spend_ap(card.cost)
    )
    |> CombatState.dispel_stealth()
    |> update_in([:current_turn, :cards_played], &((&1 || 0) + 1))  # add this line

  # ... rest unchanged
end
```

### 3. Expose in formula context

**File:** `lib/game/card.ex` — `build_effect_context/3` (line 300)

Add `"cards_played_this_turn"` to the returned map:

```elixir
defp build_effect_context(target, combat_state, cast_distance \\ nil) do
  caster = CombatState.get_current_player(combat_state)
  # ... existing encoding ...

  %{
    "caster" => caster_map,
    "target" => encode_target(target),
    "state" => state_map,
    "pull_delta" => compute_pull_delta(caster, target, combat_state),
    "push_delta" => compute_push_delta(caster, target, combat_state),
    "angle_toward_target" => compute_angle_toward(caster, target, combat_state),
    "angle_toward_caster" => compute_angle_toward(target, caster, combat_state),
    "distance_from_caster" => compute_distance_from_caster(caster, target, combat_state),
    "cast_distance" => cast_distance,
    "cards_played_this_turn" => Map.get(combat_state.current_turn, :cards_played, 0)  # add this
  }
end
```

---

## Critical Files

| File | Change |
|------|--------|
| `lib/game/combat_state.ex` | Add `cards_played: 0` to `new_turn/1` |
| `lib/game/card.ex` | Increment `current_turn.cards_played` in `process_card/3`; expose as `"cards_played_this_turn"` in `build_effect_context/3` |

---

## Verification

1. Create a card with a damage effect whose value formula is `{"*": [{"var": "cards_played_this_turn"}, 3]}`.
2. Start a combat. On a player's turn, play one card first (any card), then play the scaling card — confirm it deals 3 damage (1 card × 3). Play two cards before it — confirm 6 damage.
3. On the next player's turn, confirm `cards_played_this_turn` resets to 0.
