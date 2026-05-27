# Feature: Guided Path Formula Variables + Move Effect Refactor

## Context

The formula system provides directional variables (`angle_toward_target`, `push_delta`, etc.) that
let move effects push or pull a character one step at a time. There is no way to express "move this
character along the shortest walkable path" — needed for guided missiles, homing pulls, and
magnetic movement.

Beyond the missing guided path case, the current `Move` effect is structurally fragile:

- Three separate `process/3` clauses matched on `trajectory` atom, each duplicating the same
  angle→direction→destination arithmetic
- `do_move_dynamic/5` re-infers push vs. pull from the angle at each step, re-computing
  `direction_toward` on every tile — coupling movement execution to spatial reasoning that
  should already be resolved by the time `process/3` runs
- `angle` is an integer (0–5) that encodes a direction; `distance` is a separate scalar — together
  they describe a path implicitly, which is less expressive and harder to test than describing the
  path explicitly

**The fix:** replace the `angle` + `distance` + `trajectory` triple with a single `path` field — a
pre-computed ordered list of tile positions. All movement variants (linear, push, pull, guided A*,
teleport) become path-generating formulas evaluated before the effect runs. The move effect itself
becomes a single clause that walks the path.

---

## New Formula Variables

Three new `var` values are added to the `:effect` formula context. These join the existing family
of pre-computed spatial variables (`angle_toward_target`, `push_delta`, etc.):

| Variable | Evaluates to |
|----------|-------------|
| `linear_path_towards_target` | Straight-line tile list from target outward in the push direction |
| `linear_path_towards_caster` | Straight-line tile list from target inward toward caster |
| `guided_path_towards_target` | A* tile list from caster's position to target's position |
| `guided_path_towards_caster` | A* tile list from target's position to caster's position |
| `guided_path_towards_blast`  | A* tile list from target's position to the AoE blast origin |

Each evaluates to an ordered list of hex position maps `[%{"q" => q, "r" => r, "s" => s}, ...]`,
**excluding the starting tile, including the destination**. Empty list if unreachable or no path
exists.

The existing `angle_*` and `*_delta` variables are **retained** for backwards compatibility with
existing cards and any formula that uses them in non-move contexts (conditionals, arithmetic, etc.).

---

## Move Effect Refactor

### New `Move` struct

Replace `angle`, `distance`, and `trajectory` with a single `path` field:

```elixir
# Before
defstruct type: :move, angle: 0, distance: 1, value_label: nil, trajectory: nil

# After
defstruct type: :move, path: [], value_label: nil
```

`path` holds the pre-resolved list of tile position maps. The formula editor sets it to one of the
new path variables (or any JsonLogic expression that evaluates to a list), along with an optional
`Enum.take`-style slice to limit distance:

```json
{"move": {"path": {"var": "guided_path_towards_caster"}}}
```

To limit distance (e.g. move at most 3 steps), wrap with a `take` expression — or, if distance
limiting is common enough, keep `distance` as an optional integer field that caps the path length
at resolve time rather than encoding a direction.

**Recommended:** keep `distance` as a nullable integer cap on the resolved path, defaulting to
`nil` (no cap). This preserves the existing authoring pattern (card authors still write a distance)
while path replaces the directional angle:

```elixir
defstruct type: :move, path: [], distance: nil, value_label: nil
```

### New `process/3` — single clause

```elixir
def process(%Move{path: path, distance: distance}, target, %CombatState{} = combat_state)
    when is_list(path) do
  steps = if is_integer(distance), do: Enum.take(path, distance), else: path

  {final_target, final_grid} =
    Enum.reduce_while(steps, {target, combat_state.grid}, fn step_map, {char, grid} ->
      pos = {step_map["q"], step_map["r"], step_map["s"]}

      if not Map.has_key?(grid.tiles, pos) or Grid.tile_blocked?(grid, pos) do
        {:halt, {char, grid}}
      else
        new_grid = Grid.update_position(grid, char, char.position, pos)
        new_char = Character.move(char, pos)
        {:cont, {new_char, new_grid}}
      end
    end)

  combat_state
  |> CombatState.update_target(target, final_target)
  |> Map.put(:grid, final_grid)
end

def process(%Move{}, _target, %CombatState{} = combat_state), do: combat_state
```

The three old clauses (`linear`, `null`, default) are deleted. Their behaviours are now expressed
as path variables:

| Old trajectory | New path variable / expression |
|---------------|-------------------------------|
| default (push) | `linear_path_towards_target` |
| default (pull) | `linear_path_towards_caster` |
| `:linear` | `linear_path_towards_target` (same, but the clause previously validated path clearance — now the walker stops at first blocked tile, which is equivalent) |
| `:null` (teleport) | A single-element path `[destination]`; blocking check is skipped by using a dedicated `teleport: true` flag or a separate `Teleport` effect |

**Note on `:null` (teleport):** Teleporting to a tile regardless of obstacles is a semantically
different operation from walking a path. Rather than encoding "ignore walls" into the path walker,
extract this into a separate `Teleport` card effect (`lib/game/combat/card_effects/teleport.ex`)
with `process/3` that simply places the character at a target position. This keeps the move effect
pure: it always walks, it always stops at obstacles.

### Existing card data migration

All existing cards using the move effect need their stored JSON updated from:

```json
{"type": "move", "angle": {"var": "angle_toward_caster"}, "distance": 2}
```

to:

```json
{"type": "move", "path": {"var": "linear_path_towards_caster"}, "distance": 2}
```

Write a Mix task or migration script that rewrites `effects` on all `cards` rows containing
`"type": "move"`, mapping:
- `angle_toward_target` → `linear_path_towards_target`
- `angle_toward_caster` → `linear_path_towards_caster`
- `angle_push_from_blast` → `linear_path_towards_blast` (if applicable)
- `trajectory: "linear"` → same path variable (walker already stops at obstacles)
- `trajectory: "null"` → migrate to `Teleport` effect

---

## Implementation Plan

### 1. Add `astar_path/3` to `Grid`

**File:** `lib/game/grid.ex`

The existing `astar_path_length/3` returns `{:ok, step_count} | :unreachable`. Add a companion
that returns the full path by tracking `came_from` during traversal:

```elixir
@spec astar_path(Grid.t(), position(), position()) :: {:ok, [position()]} | :unreachable
def astar_path(%Grid{} = grid, start, goal) do
  # A* tracking came_from map; reconstruct path on success
  # Returns {:ok, [step_1, ..., goal]} — start excluded
  # Returns :unreachable if no path exists
  # Passability: occupied tiles block except goal; wall/missing tiles always block
end
```

After implementing, refactor `astar_path_length/3` to delegate to `astar_path/3` internally:

```elixir
def astar_path_length(grid, start, goal) do
  case astar_path(grid, start, goal) do
    {:ok, path} -> {:ok, length(path)}
    :unreachable -> :unreachable
  end
end
```

This eliminates the duplicate A* implementation.

### 2. Add `linear_path/3` to `Grid`

**File:** `lib/game/grid.ex`

A straight-line path generator walking from `start` in the direction of `goal`, one step per tile:

```elixir
@spec linear_path(Grid.t(), position(), position()) :: [position()]
def linear_path(%Grid{} = grid, start, goal) do
  dir = direction_toward(grid, start, goal)
  # Walk from start + dir until goal is reached or grid boundary hit
  # Returns [step_1, ..., goal] — start excluded
end
```

Unlike `has_linear_path?/3`, this does not validate clearance — it just enumerates tiles. The move
walker handles stopping at blocked tiles.

### 3. Inject path variables into the effect context

**File:** `lib/game/card.ex` — `build_effect_context/3` (around line 311)

```elixir
%{
  # ... existing keys retained ...
  "linear_path_towards_target" =>
    compute_linear_path(grid, target_position, caster_position |> direction_toward_target),
  "linear_path_towards_caster" =>
    compute_linear_path(grid, target_position, caster_position),
  "guided_path_towards_target" =>
    compute_guided_path(grid, caster.position, target_position),
  "guided_path_towards_caster" =>
    compute_guided_path(grid, target_position, caster.position),
}
```

For AoE blast context (merged alongside `angle_push_from_blast`):

```elixir
"guided_path_towards_blast"  => compute_guided_path(grid, target_position, blast_origin),
"linear_path_towards_blast"  => compute_linear_path(grid, target_position, blast_origin),
```

```elixir
defp compute_guided_path(grid, from, to) do
  case Grid.astar_path(grid, from, to) do
    {:ok, path} -> encode_path(path)
    :unreachable -> []
  end
end

defp compute_linear_path(grid, from, to) do
  grid |> Grid.linear_path(from, to) |> encode_path()
end

defp encode_path(positions) do
  Enum.map(positions, fn {q, r, s} -> %{"q" => q, "r" => r, "s" => s} end)
end
```

### 4. Refactor `Move` struct and `process/3`

**File:** `lib/game/combat/card_effects/move.ex`

Replace struct and all three `process/3` clauses with the unified implementation described above.
Delete `do_move_fixed/4` and `do_move_dynamic/5`.

Update `params/1`:

```elixir
def params(_), do: ["path", "distance"]
```

### 5. Extract `Teleport` effect

**New file:** `lib/game/combat/card_effects/teleport.ex`

```elixir
defmodule Game.Combat.CardEffects.Teleport do
  defstruct type: :teleport, destination: nil, value_label: nil

  defimpl Game.Combat.CardEffect do
    def process(%Teleport{destination: dest_formula}, target, combat_state) do
      # dest_formula resolves to a single %{"q", "r", "s"} position map
      # Place character at destination if tile exists; no obstacle check
    end
    def params(_), do: ["destination"]
    # ...
  end
end
```

Register `"teleport"` in `Game.Card`'s effect type map.

### 6. Data migration for existing cards

**New file:** `priv/repo/migrations/<ts>_migrate_move_effects_to_path.exs`

Walk all `cards` rows, decode `effects`, rewrite any `"type": "move"` effect:
- `angle_toward_target` → `"path": {"var": "linear_path_towards_target"}`
- `angle_toward_caster` → `"path": {"var": "linear_path_towards_caster"}`
- `angle_push_from_blast` → `"path": {"var": "linear_path_towards_blast"}`
- `trajectory: "null"` → convert to `"type": "teleport"` effect with matching destination formula
- Remove `angle` and `trajectory` fields; retain `distance`

### 7. Update `available_variables/1`

**File:** `lib/game/formula.ex`

Add to `available_variables(:effect)`:

```elixir
%{name: "linear_path_towards_target", description: "Straight-line tile path from target in push direction"},
%{name: "linear_path_towards_caster", description: "Straight-line tile path from target toward caster"},
%{name: "guided_path_towards_target", description: "A* path from caster to target, excluding start tile"},
%{name: "guided_path_towards_caster", description: "A* path from target to caster, excluding start tile"},
%{name: "guided_path_towards_blast",  description: "A* path from target to AoE blast origin (AoE only)"},
%{name: "linear_path_towards_blast",  description: "Straight-line path from target to blast origin (AoE only)"},
```

Retain existing `angle_*` and `*_delta` entries — they remain valid in non-move formula contexts.

### 8. Update admin UI

**File:** `lib/game_web/live/admin/fields/effect_field.ex`

Replace the `trajectory` select with a `path` formula field (same `FormulaEditorComponent` used
for other formula-valued fields). Remove `angle` and `trajectory` from the move effect field list.

---

## TDD Plan

Test bottom-up: Grid functions first, then context injection, then the move effect in isolation,
then end-to-end with formula resolution.

### Level 1 — `Grid.astar_path/3`

**File:** `test/game/grid_test.exs`

```elixir
describe "astar_path/3" do
  test "returns adjacent tile as single-step path"
  test "returns multi-step path on open grid"
  test "navigates around a wall"
  test "returns :unreachable when goal is enclosed"
  test "allows destination to be occupied; reroutes around occupied intermediate tiles"
  test "path length is consistent with astar_path_length/3"
  test "start == goal returns {:ok, []}"
end
```

### Level 2 — `Grid.linear_path/3`

**File:** `test/game/grid_test.exs`

```elixir
describe "linear_path/3" do
  test "returns tiles in a straight line toward goal"
  test "stops at grid boundary before reaching goal"
  test "does not skip occupied tiles — caller decides when to stop"
  test "start == goal returns []"
end
```

### Level 3 — Context injection

**File:** `test/game/card_test.exs`

```elixir
describe "build_effect_context/3 — path variables" do
  test "linear_path_towards_caster is a straight line ending at caster"
  test "guided_path_towards_caster navigates around a wall that blocks the linear path"
  test "guided_path_towards_target and linear_path_towards_target agree on open grid"
  test "guided path is [] when target is unreachable; linear path proceeds regardless"
  test "blast path variables are absent on non-AoE effects"
  test "blast path variables are present and correct on AoE effects"
end
```

The key test here is the third one — it documents the contract difference between linear and
guided when obstacles are present.

### Level 4 — `Move` effect unit tests

**File:** `test/game/combat/card_effects/move_test.exs`

```elixir
describe "process/3 with path" do
  test "moves character by full path when distance is nil"
  test "moves character by distance steps when distance < path length"
  test "stops at path end when distance > path length"
  test "stops before first blocked tile in path"
  test "does nothing when path is []"
  test "does nothing when path is not a list (guard clause)"
end
```

These tests construct paths directly as lists of position maps — no formula resolution needed.
They test the walker in isolation.

### Level 5 — Integration (formula → move)

**File:** `test/game/combat/card_effects/move_test.exs` or a dedicated integration test file

```elixir
describe "guided trajectory end-to-end" do
  test "guided_path_towards_caster moves target around a wall toward caster"
  test "linear_path_towards_caster moves target in straight line, stops at wall"
  test "guided_path_towards_blast pulls target toward AoE origin along walkable path"
end
```

These tests run actual card play through `Game.Card.process_card/3` with a real combat state and
grid, asserting final character position.

### What to avoid

- Do not mock `Grid` in move effect tests. The serialisation boundary (tuples → maps → tuples)
  between context injection and the move walker is exactly where bugs will hide.
- Do not test A* internals (open/closed set state, iteration count). Test path properties only:
  every step is in the grid, every intermediate step was passable at path-generation time, length
  matches `astar_path_length/3`.
- Do not write separate tests for the old `trajectory: :linear` / `:null` behaviour — those
  clauses are deleted. Write tests for the new path-walker behaviour and the new `Teleport` effect
  separately.

---

## Critical Files

| File | Change |
|------|--------|
| `lib/game/grid.ex` | Add `astar_path/3`; add `linear_path/3`; refactor `astar_path_length/3` to delegate |
| `lib/game/card.ex` | Inject path variables in `build_effect_context/3`; add `compute_guided_path/3`, `compute_linear_path/3`, `encode_path/1` |
| `lib/game/combat/card_effects/move.ex` | Replace struct + all `process/3` clauses with unified path walker; delete `do_move_fixed/4`, `do_move_dynamic/5` |
| `lib/game/combat/card_effects/teleport.ex` | New effect extracted from old `:null` trajectory |
| `lib/game/formula.ex` | Add 6 new entries to `available_variables(:effect)` |
| `lib/game_web/live/admin/fields/effect_field.ex` | Replace `angle`/`trajectory` inputs with `path` formula field |
| `priv/repo/migrations/<ts>_migrate_move_effects_to_path.exs` | Rewrite `angle`+`trajectory` → `path` in all cards |
| `test/game/grid_test.exs` | Tests for `astar_path/3` and `linear_path/3` |
| `test/game/card_test.exs` | Context injection tests for path variables |
| `test/game/combat/card_effects/move_test.exs` | Walker unit tests + integration tests |

---

## Verification

1. Run the full test suite after the migration; confirm no existing card behaviour regresses.
2. Open a card with a push move effect in admin; confirm the `path` field shows the formula editor
   pre-populated with the migrated `linear_path_towards_target` variable.
3. Play `Fireball` (push move); confirm targets are still pushed away from blast origin.
4. Play `Charge` (slide toward target); confirm character moves toward target, stops at adjacent.
5. Play `Get Over Here` (pull); confirm target is pulled toward caster, stops at first obstacle.
6. Create a new card with `path: guided_path_towards_caster`, `distance: 3` on a map with a wall
   between target and caster; confirm target moves around the wall.
7. Verify a teleport card (migrated from `trajectory: null`) places character at destination
   regardless of obstacles between start and end.
