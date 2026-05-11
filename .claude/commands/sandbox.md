# Sandbox URL Reference

Quick reference for sandbox mode URL parameters.

## URL format

```
/sandbox?characters=<classes>&map=<slug>
/sandbox?initial_state=<encoded>&map=<slug>
```

## Parameters

### `characters=` (preferred)
Comma-separated class names. Teams auto-assigned alternating (1, 2, 1, 2...). Positions auto-assigned from map spawn points, then random free non-wall tiles for overflow.

```
/sandbox?characters=fighter,mage
/sandbox?characters=fighter,mage,fighter&map=two_towers
```

### `map=`
Map slug string. Loads from DB first, falls back to builtin maps in `Game.Maps`. Nil/missing = plain dynamic grid.

```
/sandbox?characters=fighter,mage&map=two_towers
```

### `initial_state=` (legacy)
Full position encoding: `[q_r_s:class:team,...]`

```
/sandbox?initial_state=[-3_0_3:fighter:1,3_0_-3:mage:2]
```

## Parsing flow (game_live.ex)

```
params["characters"] → parse_characters/1  (no :position key)
  ↓ nil if absent
params["initial_state"] → parse_initial_state/1  (explicit positions)
  ↓ nil/error
default_sandbox_combatants()  (fighter + ranger at hardcoded coords)
```

## Position assignment (combat_builder.ex)

Specs without `:position` → `maybe_assign_positions/2`:
1. Map spawn points filled in order
2. Overflow → `:random` sentinel → resolved to shuffled free non-wall tile
