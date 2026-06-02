# Feature: Map Assets — DB-backed Terrain and Objects

## Context

Terrain types and map object types are currently hardcoded. The only terrain is `"plain"` (an
implicit default); the only object types are `Wall`, `Pickup`, and `Breakable`, each hard-wired in
`deserialize_objects/1` in `Game.Maps`. The map editor's tool list is static HTML with two
fixed buttons ("Wall" and "Terrain").

This feature makes both **terrain** and **object** types first-class DB records with slugs,
display names, and a 3D asset URL. It also reworks the map editor's tool panel into collapsible
palettes — one for terrain, one for objects — populated from the DB. Selecting any item from either
palette sets the active paint cursor to that specific asset.

---

## Scope Clarifications

- **Terrain** (`MapTerrain`) — defines a walkable tile type. The tile stores a reference to its
  terrain record via `slug`. Current behaviour: all tiles are `"plain"`. After this feature, any
  terrain slug loaded from the DB is valid. Terrain is always walkable (movement blocking is the
  concern of objects, not terrain).
- **Objects** (`MapObject`) — can be placed on a tile. The existing `Wall`, `Pickup`, and
  `Breakable` structs are not deleted; instead, a new `MapObjectType` DB record provides
  metadata (name, slug, asset URL, solidity) for editor display. The wall hard-code in the editor
  becomes an ordinary `MapObjectType` record with `slug: "wall"`, `solidity: :solid`.
- **Solidity** is the property that unifies the old type distinctions:
  - `:solid` — blocks movement (`blocks_movement? = true`)
  - `:semisolid` — blocks for some purposes (e.g. projectiles pass through, characters cannot)
  - `:immaterial` — never blocks movement
  - `:pickable` — item pickup (maps to existing `Pickup` struct)
  - `:breakable` — destructible (maps to existing `Breakable` struct)
- **Asset URL** — stored as a plain string on both record types. The 3D renderer reads it; no
  asset pipeline changes are in scope for this plan.

---

## Implementation Plan

### 1. DB schemas — `MapTerrain` and `MapObjectType`

**New files:**
- `lib/game/maps/map_terrain.ex`
- `lib/game/maps/map_object_type.ex`

#### `MapTerrain`

```elixir
defmodule Game.Maps.MapTerrain do
  use Ecto.Schema
  import Ecto.Changeset

  schema "map_terrains" do
    field :slug,        :string
    field :name,        :string
    field :asset_url,   :string
    timestamps(type: :utc_datetime)
  end

  def changeset(terrain, attrs) do
    terrain
    |> cast(attrs, [:slug, :name, :asset_url])
    |> validate_required([:slug, :name])
    |> unique_constraint(:slug)
  end
end
```

#### `MapObjectType`

```elixir
defmodule Game.Maps.MapObjectType do
  use Ecto.Schema
  import Ecto.Changeset

  @solidity_values [:solid, :semisolid, :immaterial, :pickable, :breakable]

  schema "map_object_types" do
    field :slug,      :string
    field :name,      :string
    field :asset_url, :string
    field :solidity,  Ecto.Enum, values: @solidity_values, default: :solid
    timestamps(type: :utc_datetime)
  end

  def changeset(object_type, attrs) do
    object_type
    |> cast(attrs, [:slug, :name, :asset_url, :solidity])
    |> validate_required([:slug, :name, :solidity])
    |> unique_constraint(:slug)
  end
end
```

**Migration:**

```elixir
create table(:map_terrains) do
  add :slug,      :string, null: false
  add :name,      :string, null: false
  add :asset_url, :string
  timestamps(type: :utc_datetime)
end
create unique_index(:map_terrains, [:slug])

create table(:map_object_types) do
  add :slug,      :string, null: false
  add :name,      :string, null: false
  add :asset_url, :string
  add :solidity,  :string, null: false, default: "solid"
  timestamps(type: :utc_datetime)
end
create unique_index(:map_object_types, [:slug])
```

**Seed data** (`priv/repo/seeds.exs` or a migration):

```elixir
Repo.insert!(%MapTerrain{slug: "plain", name: "Plain"})
Repo.insert!(%MapObjectType{slug: "wall",     name: "Wall",     solidity: :solid})
Repo.insert!(%MapObjectType{slug: "pickup",   name: "Pickup",   solidity: :pickable})
Repo.insert!(%MapObjectType{slug: "breakable",name: "Breakable",solidity: :breakable})
```

---

### 2. Context functions — `Game.Maps`

**File:** `lib/game/maps.ex`

Add CRUD helpers for both new schemas, following the existing `create_map/1`, `update_map/2`
pattern:

```elixir
# MapTerrain
def list_terrains, do: Repo.all(MapTerrain)
def get_terrain!(id), do: Repo.get!(MapTerrain, id)
def get_terrain_by_slug(slug), do: Repo.get_by(MapTerrain, slug: slug)
def create_terrain(attrs), do: %MapTerrain{} |> MapTerrain.changeset(attrs) |> Repo.insert()
def update_terrain(%MapTerrain{} = t, attrs), do: t |> MapTerrain.changeset(attrs) |> Repo.update()
def delete_terrain(%MapTerrain{} = t), do: Repo.delete(t)

# MapObjectType
def list_object_types, do: Repo.all(MapObjectType)
def get_object_type!(id), do: Repo.get!(MapObjectType, id)
def get_object_type_by_slug(slug), do: Repo.get_by(MapObjectType, slug: slug)
def create_object_type(attrs), do: %MapObjectType{} |> MapObjectType.changeset(attrs) |> Repo.insert()
def update_object_type(%MapObjectType{} = o, attrs), do: o |> MapObjectType.changeset(attrs) |> Repo.update()
def delete_object_type(%MapObjectType{} = o), do: Repo.delete(o)
```

---

### 3. Update `Maps.from_db/1` to use terrain slugs

**File:** `lib/game/maps.ex`

Currently: `terrain = String.to_existing_atom(tile["terrain"] || "plain")`

After: terrain remains a string slug on the tile struct. The game only needs to know whether a tile
is walkable — it does not need to call `String.to_existing_atom`. Change deserialization to keep
the slug as a string and update the one place that checks for walkability:

```elixir
terrain = tile["terrain"] || "plain"   # keep as string slug
```

Update `Grid.tile_blocked?/2` to not check for `tile[:terrain] == :wall` (that was a legacy
quirk — walls are now objects, not terrain). Remove that clause entirely:

```elixir
def tile_blocked?(%Grid{tiles: tiles}, target_position) do
  case Map.get(tiles, target_position) do
    nil  -> true
    tile -> Enum.any?(tile[:objects] || [], &Game.MapObject.blocks_movement?/1) or
            not is_nil(tile[:occupied_by])
  end
end
```

Update `game_board.ex`'s `terrain_class/2` to stop atom-matching on `:plain`/`:wall` (which was
implicit). Terrain rendering now uses the asset URL (future 3D work); for now the class logic is
unchanged — a tile with `terrain != nil` is a real tile, one with `terrain: nil` is OOB.

---

### 4. Admin LiveViews — `TerrainLive` and `ObjectTypeLive`

**New files:**
- `lib/game_web/live/admin/terrain_live.ex`
- `lib/game_web/live/admin/object_type_live.ex`

Both follow the Backpex `LiveResource` pattern exactly as `BaseCardLive` does.

#### `TerrainLive`

```elixir
defmodule GameWeb.Admin.TerrainLive do
  use Backpex.LiveResource,
    adapter_config: [
      schema: Game.Maps.MapTerrain,
      repo: Game.Repo,
      update_changeset: &Game.Maps.MapTerrain.changeset/2,
      create_changeset: &Game.Maps.MapTerrain.changeset/2
    ]

  def layout(_), do: {GameWeb.Layouts, :admin}
  def singular_name, do: "Terrain"
  def plural_name, do: "Terrains"

  def fields do
    [
      slug:      %{module: Backpex.Fields.Text, label: "Slug", searchable: true},
      name:      %{module: Backpex.Fields.Text, label: "Name", searchable: true},
      asset_url: %{module: Backpex.Fields.Text, label: "Asset URL"}
    ]
  end
end
```

#### `ObjectTypeLive`

```elixir
defmodule GameWeb.Admin.ObjectTypeLive do
  use Backpex.LiveResource,
    adapter_config: [
      schema: Game.Maps.MapObjectType,
      repo: Game.Repo,
      update_changeset: &Game.Maps.MapObjectType.changeset/2,
      create_changeset: &Game.Maps.MapObjectType.changeset/2
    ]

  def layout(_), do: {GameWeb.Layouts, :admin}
  def singular_name, do: "Object Type"
  def plural_name, do: "Object Types"

  def fields do
    [
      slug:      %{module: Backpex.Fields.Text, label: "Slug", searchable: true},
      name:      %{module: Backpex.Fields.Text, label: "Name", searchable: true},
      solidity:  %{module: Backpex.Fields.Select, label: "Solidity",
                   options: fn _ -> [solid: "Solid", semisolid: "Semisolid",
                                     immaterial: "Immaterial", pickable: "Pickable",
                                     breakable: "Breakable"] end},
      asset_url: %{module: Backpex.Fields.Text, label: "Asset URL"}
    ]
  end
end
```

**Router** — add to the `live_session :admin` block in `router.ex`:

```elixir
live_resources "/map_terrains",    Admin.TerrainLive
live_resources "/map_object_types", Admin.ObjectTypeLive
```

---

### 5. Map editor — dynamic palette replacing static tool buttons

**File:** `lib/game_web/live/admin/map_editor_live.ex`

#### Mount changes

Load terrain and object types at mount:

```elixir
def mount(%{"id" => id}, _session, socket) do
  map          = Maps.get_map!(id)
  terrains     = Maps.list_terrains()
  object_types = Maps.list_object_types()

  {:ok,
   socket
   |> assign(
     map: map,
     pending_tiles: map.tiles,
     pending_spawn_points: map.spawn_points,
     terrains: terrains,
     object_types: object_types,
     selected_tool: :spawn_point,   # default neutral tool
     dirty: false
   )
   |> assign_grid(map)}
end
```

#### `selected_tool` shape change

Previously `selected_tool` was an atom (`:wall`, `:terrain`, `:spawn_point`).

Now it is one of:
- `{:terrain, terrain_slug}` — paint this terrain type onto tiles
- `{:object, object_slug}` — toggle this object type on tiles
- `:spawn_point` — place/remove spawn points (unchanged)

#### Tool selection event

```elixir
def handle_event("select_tool", %{"kind" => "terrain", "slug" => slug}, socket),
  do: {:noreply, assign(socket, selected_tool: {:terrain, slug})}

def handle_event("select_tool", %{"kind" => "object", "slug" => slug}, socket),
  do: {:noreply, assign(socket, selected_tool: {:object, slug})}

def handle_event("select_tool", %{"kind" => "spawn_point"}, socket),
  do: {:noreply, assign(socket, selected_tool: :spawn_point)}
```

#### Tile click dispatch

Update `handle_tile_click/2` to branch on the new tuple shape:

```elixir
{pending_tiles, pending_spawn_points} =
  case socket.assigns.selected_tool do
    {:terrain, slug} ->
      apply_terrain_paint(coord, oob?, slug, pending_tiles, pending_spawn_points)

    {:object, slug} when not oob? ->
      apply_object_toggle(coord, slug, pending_tiles, pending_spawn_points)

    :spawn_point when not oob? ->
      apply_spawn_toggle(coord, pending_tiles, pending_spawn_points)

    _ ->
      {pending_tiles, pending_spawn_points}
  end
```

`apply_terrain_paint/5` — generalises `apply_terrain_toggle`. When oob, creates a new tile with
the chosen terrain slug; when existing, updates the tile's `"terrain"` key to the slug (or removes
the tile if the same terrain is re-selected, matching current toggle behaviour).

`apply_object_toggle/4` — generalises `toggle_wall_in_tiles`. Receives a slug string instead of
always inserting `%{"type" => "wall"}`. Inserts `%{"type" => slug}` or removes any object whose
`"type"` matches the slug.

#### FAB / palette render

Replace the three static buttons with two collapsible sections — one for terrain, one for objects
— plus the always-visible Spawn Point button:

```heex
<!-- Tool palette FAB -->
<div class="fab fixed bottom-8 right-8 !items-end">
  <!-- Current tool indicator -->
  <div tabindex="0" role="button" class="btn btn-lg btn-circle btn-neutral">
    <.icon name={tool_icon(@selected_tool)} class="h-6 w-6" />
  </div>

  <!-- Spawn Point (always visible) -->
  <button
    class={["btn btn-lg gap-2", @selected_tool == :spawn_point && "btn-active"]}
    phx-click="select_tool" phx-value-kind="spawn_point"
  >
    <.icon name="hero-map-pin" class="h-5 w-5" /> Spawn Point
  </button>

  <!-- Objects palette (collapsible) -->
  <details class="w-full">
    <summary class="btn btn-lg gap-2 w-full">
      <.icon name="hero-cube" class="h-5 w-5" /> Objects
    </summary>
    <div class="flex flex-col gap-1 mt-1 pl-2">
      <button
        :for={obj <- @object_types}
        class={["btn btn-md gap-2 justify-start",
                match?({:object, ^obj.slug}, @selected_tool) && "btn-active"]}
        phx-click="select_tool" phx-value-kind="object" phx-value-slug={obj.slug}
      >
        {obj.name}
      </button>
    </div>
  </details>

  <!-- Terrain palette (collapsible) -->
  <details class="w-full">
    <summary class="btn btn-lg gap-2 w-full">
      <.icon name="hero-square-2-stack" class="h-5 w-5" /> Terrain
    </summary>
    <div class="flex flex-col gap-1 mt-1 pl-2">
      <button
        :for={terrain <- @terrains}
        class={["btn btn-md gap-2 justify-start",
                match?({:terrain, ^terrain.slug}, @selected_tool) && "btn-active"]}
        phx-click="select_tool" phx-value-kind="terrain" phx-value-slug={terrain.slug}
      >
        {terrain.name}
      </button>
    </div>
  </details>
</div>
```

Update `tool_icon/1` to handle the new shapes:

```elixir
defp tool_icon({:terrain, _}),  do: "hero-square-2-stack"
defp tool_icon({:object, _}),   do: "hero-cube"
defp tool_icon(:spawn_point),   do: "hero-map-pin"
```

---

### 6. `Maps.deserialize_objects/1` — slug-driven dispatch

**File:** `lib/game/maps.ex`

The current pattern-match on hardcoded type strings can remain for `"wall"`, `"pickup"`,
`"breakable"` (backward compatibility with existing saved maps). No change is required here for
the MVP — newly placed objects of any type are stored as `%{"type" => slug}` maps, and the existing
catch-all `nil`-returning clause handles unknown slugs gracefully. However, add a generic fallback
struct for slugs that do not match a known Elixir struct:

```elixir
%{"type" => slug} ->
  case slug do
    "wall"      -> %MapObject.Wall{}
    "pickup"    -> # handled by existing clause above
    "breakable" -> # handled by existing clause above
    _other      -> %MapObject.Generic{slug: slug}
  end
```

**New file:** `lib/game/map_objects/generic.ex`

```elixir
defmodule Game.MapObject.Generic do
  defstruct slug: nil, blocks_movement: false

  defimpl Game.MapObject do
    def blocks_movement?(%{blocks_movement: b}), do: b
    def on_enter(_obj, _character, state), do: {:ok, state}
  end
end
```

`blocks_movement` on `Generic` can be resolved at load time by joining against `MapObjectType`:
look up the slug, map `solidity` to a boolean (`:solid` / `:semisolid` → `true`, rest → `false`).
This join happens in `Maps.from_db/1`, not in the struct itself.

---

## TDD Plan

### `test/game/maps/map_terrain_test.exs` (new)

```elixir
describe "MapTerrain changeset" do
  test "valid with slug and name"
  test "invalid without slug"
  test "invalid without name"
  test "slug must be unique"
end

describe "Maps context — terrain CRUD" do
  test "list_terrains/0 returns all terrain records"
  test "get_terrain_by_slug/1 returns the matching record"
  test "create_terrain/1 persists a new terrain"
  test "update_terrain/2 changes fields"
  test "delete_terrain/1 removes the record"
end
```

### `test/game/maps/map_object_type_test.exs` (new)

```elixir
describe "MapObjectType changeset" do
  test "valid with slug, name, solidity"
  test "invalid solidity value is rejected"
  test "slug must be unique"
end

describe "Maps context — object_type CRUD" do
  test "list_object_types/0 returns all records"
  test "get_object_type_by_slug/1 returns matching record"
  test "create/update/delete follow the same pattern as terrain"
end
```

### `test/game_web/live/admin/terrain_live_test.exs` (new)

```elixir
describe "TerrainLive" do
  test "lists terrain records"
  test "creates a new terrain via the form"
  test "edits a terrain"
  test "deletes a terrain"
end
```

Pattern mirrors `base_card_live_test.exs`: `register_and_log_in_admin`, `live(conn, "/admin/map_terrains")`, interact via Backpex-rendered form.

### `test/game_web/live/admin/object_type_live_test.exs` (new)

Same structure as `terrain_live_test.exs` for `/admin/map_object_types`.

### `test/game_web/live/map_editor_live_test.exs` — extend existing

```elixir
describe "dynamic terrain palette" do
  test "terrain buttons are rendered from DB records, not hardcoded"
  test "selecting a terrain sets selected_tool to {:terrain, slug}"
  test "clicking a tile with terrain tool paints that terrain slug onto the tile"
  test "clicking same terrain on existing tile removes it (toggle)"
end

describe "dynamic object palette" do
  test "object buttons are rendered from DB object_type records"
  test "selecting an object sets selected_tool to {:object, slug}"
  test "clicking a tile with object tool places that object type"
  test "clicking same object type again removes it (toggle)"
  test "clicking an OOB tile with object tool does nothing"
end
```

### `test/game/grid_test.exs` — update movement blocking tests

```elixir
describe "tile_blocked? without wall terrain" do
  test "tile with no blocking objects is not blocked"
  test "tile with a Wall object is blocked"
  test "plain terrain slug does not affect movement"
end
```

---

## Critical Files

| File | Change |
|------|--------|
| `lib/game/maps/map_terrain.ex` | **New** — `MapTerrain` Ecto schema |
| `lib/game/maps/map_object_type.ex` | **New** — `MapObjectType` Ecto schema |
| `lib/game/map_objects/generic.ex` | **New** — fallback `MapObject.Generic` struct for DB-only types |
| `priv/repo/migrations/<ts>_create_map_asset_tables.exs` | **New** — creates both tables |
| `lib/game/maps.ex` | Add CRUD helpers for both new schemas; update `from_db` terrain deserialization to keep slug as string; update `deserialize_objects` with generic fallback |
| `lib/game/grid.ex` | Remove `tile[:terrain] == :wall` clause from `tile_blocked?/2` |
| `lib/game_web/live/admin/terrain_live.ex` | **New** — Backpex admin for `MapTerrain` |
| `lib/game_web/live/admin/object_type_live.ex` | **New** — Backpex admin for `MapObjectType` |
| `lib/game_web/router.ex` | Add `live_resources` for both new admin lives |
| `lib/game_web/live/admin/map_editor_live.ex` | Load terrains + object_types at mount; change `selected_tool` shape; update event handlers; replace static FAB buttons with dynamic palettes |

---

## Migration Notes

- Existing saved maps continue to work. Their tile `"terrain"` is already `"plain"` — a string
  slug that will match the seeded `MapTerrain` record. No data migration needed.
- Existing `"wall"` objects continue to deserialize as `%MapObject.Wall{}` via the existing clause
  in `deserialize_objects/1`.
- The `tile[:terrain] == :wall` check in `grid.ex` is removed; there are no maps in the DB where
  terrain is `"wall"` (walls have always been objects, the check was dead code).

---

## Verification

1. Run seeds — confirm `plain` terrain and `wall`/`pickup`/`breakable` object types are present.
2. Visit `/admin/map_terrains` — create a new terrain (e.g. "Lava", slug `"lava"`).
3. Visit `/admin/map_object_types` — create a new object type (e.g. "Pillar", slug `"pillar"`, solidity `:solid`).
4. Open the map editor — confirm both palette sections appear, each listing DB records.
5. Select "Lava" from the terrain palette — paint tiles and save — confirm `"terrain": "lava"` appears in the DB.
6. Select "Pillar" from the object palette — place on a tile and save — confirm `%{"type": "pillar"}` appears in the tile's objects array.
7. In combat, confirm characters cannot walk through a "Pillar" tile (solidity `:solid` → `blocks_movement: true`).
8. Confirm "Wall" tool in the editor still works for backward compatibility.
