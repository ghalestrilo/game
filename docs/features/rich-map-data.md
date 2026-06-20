# Feature: Rich Map Data Structure

## Context

Maps currently store hex tiles (terrain + objects) and spawn points as JSONB columns on the
`maps` table. The game logic is solid, but maps feel like a game board rather than a world.
What's missing:

- A **string-keyed asset registry** embedded in the map — a `slug → url` table that tiles,
  decorations, and landscape props can all reference, keeping the map fully self-contained.
- A **per-tile decoration layer** — visual props placed on a tile (bushes, crates, torches)
  that are purely cosmetic and never affect movement or gameplay.
- **World-space props** — large landscape elements (mountains, ruins, trees) placed at arbitrary
  float `{x, y, z}` coordinates with configurable `:scale`, independent of the hex grid.
- **Explicit movement blocking** — the ability to mark arbitrary tile coordinates as non-steppable
  without placing a wall object, so that a mountain or large prop can feel physically present
  and path-blocking.

All new data lives inside the `maps` table as additional JSONB columns. Maps stay fully
self-contained and portable — no join tables, no foreign keys.

---

## Scope Clarifications

- **Asset registry** (`maps.assets`) — a `%{"slug" => "https://.../asset.glb"}` map stored as a
  single JSONB column. The 3D renderer resolves slugs to URLs from this table. Both decorations
  and props reference assets by slug.
- **Tile decorations** — stored inline inside the existing `tiles` JSONB array, in a
  `"decorations"` key on each tile entry. No schema change to the array structure — tiles already
  accept arbitrary maps.
- **World-space props** (`maps.props`) — a `{:array, :map}` JSONB column. Each entry has
  `"asset"` (slug), `"x"`, `"y"`, `"z"` (floats), and `"scale"` (float). Props are not tied to
  any hex coordinate; the renderer places them at the given world position.
- **Blocked coords** (`maps.blocked_coords`) — a `{:array, :map}` JSONB column of
  `%{"q" => int, "r" => int, "s" => int}` entries. At combat start these are loaded into a
  `MapSet` on `CombatState` and checked by `Grid.tile_blocked?/3` as an additive gate on top
  of object solidity.
- **No gameplay changes** — `MapObject` solidity and `MapObject.blocks_movement?/1` remain
  untouched. `blocked_coords` is a second, independent input to the movement check.
- **Map editor** — the existing `MapEditorLive` gains an asset management panel and three new
  tools (decoration brush, block-tile toggle, prop placer). All new state follows the existing
  `pending_*` pattern and is persisted on the main Save action.

---

## Data Shapes

### `maps.assets` (`:map`, `default: %{}`)

```json
{
  "oak_tree":   "https://cdn.example.com/assets/oak_tree.glb",
  "bush_small": "https://cdn.example.com/assets/bush_small.glb",
  "mountain_a": "https://cdn.example.com/assets/mountain_a.glb"
}
```

### Tile entry with decorations (inside `maps.tiles`)

```json
{
  "q": 2, "r": -1, "s": -1,
  "terrain": "grass",
  "objects": [{"type": "wall"}],
  "decorations": [
    {"asset": "bush_small", "offset_x": 0.3, "offset_z": -0.2, "scale": 0.8},
    {"asset": "rock_flat"}
  ]
}
```

`offset_x`, `offset_z`, and `scale` are optional; defaults are `0.0`, `0.0`, and `1.0`.

### `maps.props` (`{:array, :map}`, `default: []`)

```json
[
  {"asset": "mountain_a", "x": 12.5, "y": 0.0, "z": -8.0, "scale": 3.0},
  {"asset": "oak_tree",   "x": 4.0,  "y": 0.0, "z":  2.0, "scale": 1.5}
]
```

### `maps.blocked_coords` (`{:array, :map}`, `default: []`)

```json
[
  {"q": 1, "r": -1, "s": 0},
  {"q": 2, "r": -2, "s": 0}
]
```

---

## Implementation Plan

### 1. Migration — add three columns to `maps`

**New file:** `priv/repo/migrations/<ts>_add_rich_map_data.exs`

```elixir
defmodule Game.Repo.Migrations.AddRichMapData do
  use Ecto.Migration

  def change do
    alter table(:maps) do
      add :assets,         :map,           default: %{}
      add :props,          {:array, :map}, default: []
      add :blocked_coords, {:array, :map}, default: []
    end
  end
end
```

No data migration needed — all existing maps gain empty defaults.

---

### 2. `Game.Maps.Map` schema

**File:** `lib/game/maps/map.ex`

```elixir
field :assets,         :map,           default: %{}
field :props,          {:array, :map}, default: []
field :blocked_coords, {:array, :map}, default: []
```

Update `changeset/2` to cast the three new fields:

```elixir
|> cast(attrs, [:slug, :display_name, :tiles, :spawn_points, :assets, :props, :blocked_coords])
```

---

### 3. `MapTemplate` struct

**File:** `lib/game/maps.ex`

Extend the struct definition:

```elixir
defmodule Game.Maps.MapTemplate do
  @type prop :: %{asset: String.t(), x: float, y: float, z: float, scale: float}
  @type decoration :: %{asset: String.t(), offset_x: float, offset_z: float, scale: float}

  @type t() :: %__MODULE__{
    name:           atom() | String.t(),
    display_name:   String.t(),
    tiles:          %{{integer(), integer(), integer()} => map()},
    spawn_points:   %{atom() => {integer(), integer(), integer()}},
    assets:         %{String.t() => String.t()},
    props:          [prop()],
    blocked_coords: MapSet.t()
  }

  defstruct name: nil, display_name: nil, tiles: %{}, spawn_points: %{},
            assets: %{}, props: [], blocked_coords: MapSet.new()
end
```

---

### 4. `Maps.from_db/1`

**File:** `lib/game/maps.ex`

Extend the existing `from_db/1` to deserialize all three new columns, and add decoration
deserialization inside the tile loop:

```elixir
def from_db(%Map{} = db_map) do
  tiles =
    Elixir.Map.new(db_map.tiles, fn tile ->
      coords      = {tile["q"], tile["r"], tile["s"]}
      terrain     = String.to_existing_atom(tile["terrain"] || "plain")
      objects     = deserialize_objects(tile["objects"] || [])
      decorations = deserialize_decorations(tile["decorations"] || [])
      {coords, %{terrain: terrain, objects: objects, decorations: decorations}}
    end)

  spawn_points =
    Elixir.Map.new(db_map.spawn_points, fn {key, [q, r, s]} ->
      {String.to_atom(key), {q, r, s}}
    end)

  props =
    Enum.map(db_map.props || [], fn p ->
      %{asset: p["asset"], x: p["x"] || 0.0, y: p["y"] || 0.0,
        z: p["z"] || 0.0, scale: p["scale"] || 1.0}
    end)

  blocked_coords =
    (db_map.blocked_coords || [])
    |> Enum.map(fn %{"q" => q, "r" => r, "s" => s} -> {q, r, s} end)
    |> MapSet.new()

  %MapTemplate{
    name:           db_map.slug,
    display_name:   db_map.display_name,
    tiles:          tiles,
    spawn_points:   spawn_points,
    assets:         db_map.assets || %{},
    props:          props,
    blocked_coords: blocked_coords
  }
end

defp deserialize_decorations(decorations) do
  Enum.map(decorations, fn d ->
    %{asset: d["asset"], offset_x: d["offset_x"] || 0.0,
      offset_z: d["offset_z"] || 0.0, scale: d["scale"] || 1.0}
  end)
end
```

---

### 5. `Grid.tile_blocked?/2` → `/3`

**File:** `lib/game/grid.ex`

Add an optional third argument defaulting to an empty `MapSet`:

```elixir
def tile_blocked?(%Grid{} = grid, position, blocked_coords \\ MapSet.new()) do
  MapSet.member?(blocked_coords, position) or
    case Map.get(grid.tiles, position) do
      nil  -> true
      tile -> Enum.any?(tile[:objects] || [], &Game.MapObject.blocks_movement?/1) or
              not is_nil(tile[:occupied_by])
    end
end
```

All existing call sites continue to compile and behave identically — the third argument is
optional and defaults to empty.

---

### 6. `CombatState`

**File:** `lib/game/combat_state.ex`

```elixir
field :blocked_coords, :any, default: MapSet.new()
```

---

### 7. `CombatBuilder`

**File:** `lib/game/combat_builder.ex`

When building the combat state from a `MapTemplate`, populate `blocked_coords`:

```elixir
%CombatState{
  grid:           build_grid(template, player_specs),
  blocked_coords: template.blocked_coords,
  # ... rest unchanged
}
```

---

### 8. Map editor — asset panel + three new tools

**File:** `lib/game_web/live/admin/map_editor_live.ex`

#### Mount — load new state

```elixir
|> assign(
  pending_assets:         map.assets || %{},
  pending_props:          map.props || [],
  pending_blocked_coords: deserialize_blocked_set(map.blocked_coords)
)
```

#### `selected_tool` — new variants

| Variant | Behaviour |
|---|---|
| `{:decoration, asset_slug}` | Appends `%{"asset" => slug}` to tile's `"decorations"` list; clicking same slug on same tile removes it |
| `:block_tile` | Toggles coordinate in `pending_blocked_coords`; visualised as a cross-hatch overlay on the tile |
| `:place_prop` | Active: submitting the prop form adds an entry to `pending_props` |

#### Asset panel (always visible in editor sidebar)

A list of `{slug, url}` pairs from `pending_assets`. Each row has edit and delete buttons. A
"+ Add Asset" row with two text inputs (`slug`, `url`) and an Add button inserts into
`pending_assets`. This is saved as `maps.assets` on the main Save action.

#### Save

```elixir
Maps.update_map(map, %{
  tiles:          pending_tiles,
  spawn_points:   pending_spawn_points,
  assets:         pending_assets,
  props:          pending_props,
  blocked_coords: Enum.map(MapSet.to_list(pending_blocked_coords),
                    fn {q, r, s} -> %{"q" => q, "r" => r, "s" => s} end)
})
```

---

## TDD Plan

### `test/game/maps_test.exs` — extend `from_db`

```elixir
describe "from_db/1 — new fields" do
  test "empty assets/props/blocked_coords fall back to defaults"
  test "assets map is passed through as-is"
  test "props list deserializes float coords and scale with defaults for missing keys"
  test "blocked_coords deserializes to a MapSet of {q,r,s} tuples"
  test "tile decorations list deserializes asset slug and optional offsets"
  test "tile with no decorations key yields empty decorations list"
end
```

### `test/game/grid_test.exs` — extend `tile_blocked?`

```elixir
describe "tile_blocked?/3 with blocked_coords" do
  test "tile_blocked?/2 backward compat: passable tile without blocked_coords arg → false"
  test "coord present in blocked_coords → true regardless of objects"
  test "coord not in blocked_coords, passable tile → false"
  test "coord not in blocked_coords, wall object present → true"
end
```

### `test/game_web/live/admin/map_editor_live_test.exs` — extend

```elixir
describe "asset panel" do
  test "adding a slug+url entry updates pending_assets"
  test "editing an existing entry changes its URL"
  test "removing a slug removes it from pending_assets"
end

describe "decoration tool" do
  test "selecting {:decoration, slug} sets selected_tool"
  test "clicking a tile appends the decoration to pending_tiles"
  test "clicking the same slug again removes the decoration from that tile"
end

describe "block_tile tool" do
  test "clicking a tile adds coord to pending_blocked_coords"
  test "clicking a blocked tile again removes it (toggle)"
end

describe "place_prop" do
  test "submitting the form appends entry to pending_props"
end

describe "save" do
  test "persists assets, props, blocked_coords alongside tiles and spawn_points"
end
```

---

## Critical Files

| File | Change |
|------|--------|
| `priv/repo/migrations/<ts>_add_rich_map_data.exs` | **New** — adds `assets`, `props`, `blocked_coords` columns |
| `lib/game/maps/map.ex` | Add three fields; update `changeset/2` |
| `lib/game/maps.ex` | Extend `MapTemplate` struct; update `from_db/1`; add `deserialize_decorations/1` |
| `lib/game/grid.ex` | Add optional `blocked_coords` arg to `tile_blocked?` |
| `lib/game/combat_state.ex` | Add `blocked_coords: MapSet.new()` field |
| `lib/game/combat_builder.ex` | Populate `blocked_coords` from `template.blocked_coords` |
| `lib/game_web/live/admin/map_editor_live.ex` | Asset panel; decoration, block_tile, place_prop tools |

---

## Migration Notes

- All three new columns default to empty — existing maps and all existing tests continue to work
  with no changes.
- `Grid.tile_blocked?/2` gains an optional third argument — zero call sites need updating.
- The `MapTemplate` struct gains three new fields with struct defaults — pattern matches that
  don't mention them are unaffected.

---

## Verification

1. Run migration — confirm `assets`, `props`, and `blocked_coords` columns exist on `maps`.
2. In the map editor, add an asset `"oak_tree"` → save → confirm `maps.assets` in the DB.
3. Use the decoration tool on a tile → save → confirm `"decorations"` key in that tile's JSON.
4. Use the block tool on a tile → save → confirm the coordinate appears in `maps.blocked_coords`.
5. Place a prop (`oak_tree`, x=12.5, y=0, z=-8, scale=3) → save → confirm entry in `maps.props`.
6. In IEx: `Game.Maps.get("your_slug")` — inspect `template.blocked_coords` (should be `MapSet`),
   `template.props` (list of maps), and a tile's `:decorations` list.
7. Start a combat — attempt to move onto a `blocked_coords` tile — confirm the move is rejected.
8. Load an existing map that has none of the new fields — confirm it loads without error.
