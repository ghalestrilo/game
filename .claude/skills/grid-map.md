# grid-map

Design, debug, or modify hex grid maps, movement, and positional card effects.

## Hex coordinate system

This game uses **cube coordinates** `{q, r, s}` where `q + r + s = 0` always.

```
         {0,-1,+1}  {+1,-1, 0}
    {-1, 0,+1}  {0, 0, 0}  {+1, 0,-1}
         {-1,+1, 0}  {0,+1,-1}
```

Distance between two tiles = `max(|Δq|, |Δr|, |Δs|)` — implemented in `Grid.distance/3`.

The six hex directions (angle indices 0–5, clockwise from east):

| Angle | Direction `{q, r, s}` |
|---|---|
| 0 | `{+1, 0, -1}` |
| 1 | `{+1, -1, 0}` |
| 2 | `{0, -1, +1}` |
| 3 | `{-1, 0, +1}` |
| 4 | `{-1, +1, 0}` |
| 5 | `{0, +1, -1}` |

Key functions in `lib/game/grid.ex`:

| Function | What it does |
|---|---|
| `Grid.distance(grid, a, b)` | Hex distance between two coordinates |
| `Grid.tiles_in_range(grid, origin, radius)` | All tiles within radius of origin |
| `Grid.direction_toward(grid, from, to)` | Unit direction vector `{q,r,s}` pointing from→to |
| `Grid.direction_from_angle(angle)` | Convert angle integer 0–5 to `{q,r,s}` vector |
| `Grid.get_object(grid, pos)` | `{:ok, character_or_nil}` at position |
| `Grid.tile_blocked?(grid, pos)` | True if occupied or out of bounds |
| `Grid.move_toward(grid, pos, direction, steps)` | Step along a direction, stopping at walls |

## Positional formula variables

These are available in card effect formulas (see `/formula-debug` for full context reference):

| Variable | Type | Description |
|---|---|---|
| `distance_from_caster` | integer | Hex distance between caster and target at resolution time |
| `cast_distance` | integer | Distance at card selection time (frozen — unaffected by movement effects on the same card) |
| `push_delta` | `{q,r,s}` map | Unit direction from caster toward target — use as `angle` for a move effect to push target away |
| `pull_delta` | `{q,r,s}` map | Unit direction from target toward caster — use as `angle` for a move effect to pull target in |
| `angle_toward_target` | integer 0–5 | Angle from caster toward target |
| `angle_toward_caster` | integer 0–5 | Angle from target toward caster |
| `angle_push_from_blast` | integer 0–5 | (AoE only) Angle from blast origin toward each target |
| `angle_pull_from_blast` | integer 0–5 | (AoE only) Angle from each target toward blast origin |
| `push_delta_from_blast` | `{q,r,s}` map | (AoE only) Direction vector away from blast origin |
| `pull_delta_from_blast` | `{q,r,s}` map | (AoE only) Direction vector toward blast origin |

## Designing movement card effects

The `move` effect takes `angle` (direction) and `distance` (steps):

```elixir
# Push target 2 tiles away from caster
%{"type" => "move", "angle" => %{"var" => "angle_toward_target"}, "distance" => 2}

# Pull target 1 tile toward caster
%{"type" => "move", "angle" => %{"var" => "angle_toward_caster"}, "distance" => 1}

# Teleport (move) self toward target — use target_formula "self"
%{"type" => "move",
  "angle" => %{"var" => "angle_toward_target"},
  "distance" => %{"+" => [1, %{"var" => "cast_distance"}]},
  "target_formula" => %{"alias" => ["self"]}}

# AoE knockback — each target pushed away from blast center
%{"type" => "move",
  "angle" => %{"var" => "angle_push_from_blast"},
  "distance" => 1,
  "range" => 2}
```

`target_formula` overrides which character the effect applies to. Common aliases:
- `{"alias": ["self"]}` — the caster
- `{"alias": ["target"]}` — the selected target (default)

## Designing AoE card effects

Any effect with `"range" > 0` becomes AoE. The `"range"` value is the blast radius in hex tiles.

```elixir
# Damage everyone within 2 tiles of the blast tile
%{"type" => "damage", "value" => 8, "range" => 2}

# Combine with knockback on the same card:
effects: [
  %{"type" => "damage", "value" => 8, "range" => 2},
  %{"type" => "move", "angle" => %{"var" => "angle_push_from_blast"}, "distance" => 1, "range" => 2}
]
```

For tile-targeting AoE cards, set `targeting: %{"type" => "tile"}` on the card.

**AoE notes:**
- Formula values are resolved per-target (each hit gets its own context with that target's `push_delta_from_blast`, etc.)
- Stealth does NOT protect against AoE — characters in the blast radius are always hit
- Effects in the same card are applied sequentially; later effects see HP changes from earlier ones

## Building a map in code

Maps are defined as `%Grid{tiles: %{coord => %{terrain: :plain, occupied_by: nil}}}`.

```elixir
# Minimal 1D corridor, 5 tiles wide
grid = %Game.Grid{
  tiles: %{
    {0, 0, 0}  => %{terrain: :plain, occupied_by: nil},
    {1, 0, -1} => %{terrain: :plain, occupied_by: nil},
    {2, 0, -2} => %{terrain: :plain, occupied_by: nil},
    {3, 0, -3} => %{terrain: :plain, occupied_by: nil},
    {4, 0, -4} => %{terrain: :plain, occupied_by: nil},
  }
}

# Place a character
grid = put_in(grid.tiles[{1, 0, -1}].occupied_by, my_character)
```

Wall objects block movement and are rendered differently on the board:

```elixir
{0, 0, 0} => %{terrain: :plain, occupied_by: nil, objects: [%Game.MapObject.Wall{}]}
```

## Testing positional logic in IEx

```elixir
# Verify distance
Game.Grid.distance(grid, {0, 0, 0}, {3, 0, -3})   # → 3

# Get tiles within radius 2 of a blast
Game.Grid.tiles_in_range(grid, {3, 0, -3}, 2)

# Get direction from caster to target
Game.Grid.direction_toward(grid, {0, 0, 0}, {3, 0, -3})  # → {1, 0, -1}

# Simulate a move effect manually
target_pos = {2, 0, -2}
direction = {1, 0, -1}
new_pos = Game.Grid.move_toward(grid, target_pos, direction, 1)
```

## Common mistakes

- **`angle_push_from_blast` is nil outside AoE**: guard with `{"if": [{"var": "angle_push_from_blast"}, ..., fallback]}` if the same effect is used on both AoE and single-target cards
- **`cast_distance` can be nil** for self-targeting cards — guard before arithmetic
- **Off-by-one in blast radius**: `"range" => 1` hits tiles at distance 0 AND 1 from the blast tile (i.e. the blast tile itself plus its 6 neighbours)
- **`push_delta` vs `angle_toward_target`**: `push_delta` is a `{q,r,s}` vector, used directly as the `angle` in a move effect. `angle_toward_target` is an integer 0–5. The move effect's `angle` field accepts both.
- **Out-of-bounds tiles**: `Grid.tiles_in_range` only returns tiles that exist in the grid — missing tiles are silently skipped by the AoE loop
