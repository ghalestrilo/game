# map-editor

Create, edit, and persist game maps — covering the DB schema, data pipeline, admin visual editor, and content sync.

## Data pipeline: DB → MapTemplate → Grid

Maps flow through three representations:

```
Game.Maps.Map (DB / Ecto schema)
  tiles: [%{"q" => int, "r" => int, "s" => int, "terrain" => string, "objects" => [...]}]
  spawn_points: %{"team_1" => [q, r, s], "team_2" => [q, r, s]}
        ↓ Game.Maps.from_db/1
Game.Maps.MapTemplate (in-memory)
  tiles: %{{q,r,s} => %{terrain: :plain, objects: [%MapObject.Wall{}, ...]}}
  spawn_points: %{team_1: {q, r, s}, team_2: {q, r, s}}
        ↓ CombatBuilder.build_grid/2
Game.Grid (combat runtime)
  tiles: %{{q,r,s} => %{terrain: :plain, occupied_by: nil, objects: [...]}}
```

Key conversions:
- DB `"terrain"` string → atom via `String.to_atom/1` (NOT `to_existing_atom` — new team names may not be interned)
- DB spawn `[q,r,s]` list → tuple `{q,r,s}` at MapTemplate stage
- `CombatBuilder.build_grid/2` overlays MapTemplate tiles onto a plain `Grid.new/1` base

## DB schema

```elixir
schema "maps" do
  field :slug, :string           # unique identifier used in lobby/sandbox URLs
  field :display_name, :string
  field :tiles, {:array, :map}   # raw JSON tiles — see structure above
  field :spawn_points, :map      # raw JSON spawn points
end
```

## MapObject serialization

Objects in `tile["objects"]` are plain maps in the DB, deserialized by `Game.Maps.deserialize_objects/1`:

| DB map | Struct |
|--------|--------|
| `%{"type" => "wall"}` | `%Game.MapObject.Wall{}` |
| `%{"type" => "pickup", "item" => "potion", "quantity" => 1}` | `%Game.MapObject.Pickup{item: :potion, quantity: 1}` |
| `%{"type" => "breakable", "hp" => 2, "max_hp" => 2, "blocks_movement" => true}` | `%Game.MapObject.Breakable{...}` |

Walls block movement and render with amber styling. Only one occupant per tile (wall, spawn point, or character).

## Context API (`Game.Maps`)

```elixir
Game.Maps.get(slug)              # → MapTemplate | nil  (checks DB first, falls back to @builtin_maps)
Game.Maps.from_db(db_map)        # → MapTemplate  (public — use to build editor grids)
Game.Maps.get_map!(id)           # → %Game.Maps.Map{}  (raises if not found)
Game.Maps.create_map(attrs)      # → {:ok, map} | {:error, changeset}
Game.Maps.update_map(map, attrs) # → {:ok, map} | {:error, changeset}
Game.Maps.list_db()              # → [%Game.Maps.Map{}]
```

## Admin visual editor

**Routes** (inside `:admin` live_session):
```elixir
live_resources "/maps", Admin.MapLive           # index / show / create / edit (Backpex)
live "/maps/:id/edit-tiles", Admin.MapEditorLive  # visual tile editor
```

**`MapEditorLive` state:**
- `map` — the last-saved `%Game.Maps.Map{}`
- `pending_tiles` — in-memory tile list, updated on every click, NOT persisted until Save
- `pending_spawn_points` — in-memory spawn points map, same lifecycle
- `selected_tool` — `:wall` | `:spawn_point`
- `dirty` — true when pending state differs from saved state
- `grid` — `%Game.Grid{}` built from pending state for display
- `spawn_points` — deserialized `%{team_atom => {q,r,s}}` passed to GameBoard

**Tool behaviour:**
- `:wall` — toggles `%{"type" => "wall"}` in the tile's `objects` list; clears any spawn point on that tile
- `:spawn_point` — assigns next free `"team_N"` slot; clears walls on that tile; clicking an existing spawn point removes it

**Save** — persists both `pending_tiles` and `pending_spawn_points` via `Maps.update_map/2`.

**Exit guard** — back button uses `JS.navigate` when clean; calls `show_modal("exit-modal")` when dirty.

## GameBoard in edit context

Pass these extra props to `<.live_component module={GameWeb.GameBoard} ...>`:

| Prop | Value | Effect |
|------|-------|--------|
| `context` | `:edit` | Enables spawn point rendering; suppresses combat overlays |
| `static_map` | `true` | Uses `phx-update="replace"` so tile re-renders after each edit |
| `spawn_points` | `%{team_atom => {q,r,s}}` | Highlights spawn tiles with blue ring + team label |

In `:edit` context, each spawn point tile shows a small label (`T1`, `T2`, …) and a `ring-info` highlight. In `:combat` context (default), these are hidden entirely.

## Building an editor grid manually

```elixir
alias Game.{Grid, Maps}

map = Maps.get_map!(id)
template = Maps.from_db(map)
radius = 4

base = Grid.new({radius, radius, radius})

overlay =
  Map.new(template.tiles, fn {coords, tile_data} ->
    base_tile = Map.get(base.tiles, coords, %{terrain: :plain, occupied_by: nil})
    {coords, Map.merge(base_tile, tile_data)}
  end)

grid = %{base | tiles: Map.merge(base.tiles, overlay)}
```

## Spawn point key conventions

- DB keys are strings: `"team_1"`, `"team_2"`, …
- MapTemplate keys are atoms: `:team_1`, `:team_2`, …
- Use `String.to_atom/1` (not `to_existing_atom`) when deserializing — new team numbers may not be interned yet
- `next_team_key/1` finds the lowest unused `"team_N"` slot (gaps from deletions get backfilled)

## Content sync

Maps are included in the push/pull content sync tasks:

```bash
mix game.push_content_sync   # local → production
mix game.pull_content_sync   # production → local
```

Maps are synced as-is (no ID remapping needed — no foreign keys). The sync deletes all prod maps and re-inserts from local.

## Common mistakes

- **`String.to_existing_atom` on team keys** — crashes if the atom hasn't been interned. Always use `String.to_atom` for team key deserialization.
- **Dropping spawn_points in `from_db` calls** — passing `spawn_points: %{}` will silently discard spawn data. Pass the real map struct.
- **`phx-update="ignore"` on the map layer** — the game board uses this by default so JS owns character positions. The editor must pass `static_map={true}` to override this with `replace`, otherwise wall changes don't re-render.
- **Tile click routing** — `phx-update="ignore"` regions bypass LiveComponent event handling; tile clicks fire `handle_event("interact", ...)` directly on the parent LiveView, not via `handle_info`. Always handle both.
- **Save includes both tiles and spawn_points** — `Maps.update_map(map, %{tiles: ..., spawn_points: ...})`. Omitting `spawn_points` will silently revert spawn changes to the last saved state.
