# TDD Combat Feature

Guide for test-driving new combat behavior in this codebase.

## Test file locations

| What | File |
|------|------|
| Combat actions (move, play_card, skip_turn) | `test/game/combat_test.exs` |
| Card overlay / JSON serialization | `test/game/combat_test.exs` — `"build_tile_overlay with map objects"` describe |
| CombatBuilder / position assignment | `test/game/combat_builder_test.exs` |
| Sandbox URL params / LiveView rendering | `test/game_web/live/sandbox_live_test.exs` |
| Specific card behaviors | `test/game/seeds/<card_name>_test.exs` |

## Setup pattern (combat_test.exs)

Tests use `Game.Fixtures` (pure in-memory, no DB) for characters and cards:

```elixir
setup do
  fighter = Fixtures.fighter()
  mage = Fixtures.mage()
  grid = %Grid{tiles: %{
    {0,0,0} => %{terrain: :plain, occupied_by: fighter},
    {1,0,-1} => %{terrain: :plain, occupied_by: mage},
  }}
  combat_state = %CombatState{
    state: :running,
    __constants__: %{players: [fighter, mage]},
    queue: [mage],
    grid: grid,
    current_turn: %{player: fighter, card: nil, starting_position: {0,0,0}}
  }
  {:ok, combat_state: combat_state, fighter: fighter, mage: mage}
end
```

## Key invariants

- `combat.queue` excludes the current player — use `CombatState.get_current_queue(combat)` to get all characters
- `tile_blocked?` returns true for: nil tile, `:wall` terrain, wall `MapObject`, or `occupied_by != nil`
- Any `MapObject` struct on a tile **must** have `@derive Jason.Encoder` — test with `Card.build_tile_overlay/2`
- `CombatBuilder.build/2` accepts specs without `:position`; they get auto-placed via spawn points then random free tiles

## DB-dependent tests

`CombatBuilder` tests need real DB classes. Call `Game.DataCase.seed_base_classes()` in setup:

```elixir
use Game.DataCase, async: false
setup do: Game.DataCase.seed_base_classes()
```

LiveView tests (`ConnCase`) call `seed_base_classes()` automatically.

## Regression checklist for map-related changes

- [ ] `mix test test/game/combat_test.exs` — core combat still works
- [ ] `mix test test/game/combat_builder_test.exs` — position assignment
- [ ] `mix test test/game_web/live/sandbox_live_test.exs` — URL params + rendering
- [ ] `mix test` — full suite
