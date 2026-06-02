# Feature: Generative Maps

## Prerequisites

This feature **requires the Map Assets feature** (`docs/features/map-assets.md`) to be implemented
first. Specifically it depends on:
- `MapTerrain` and `MapObjectType` DB schemas with slug-based tile data
- `Maps.list_terrains/0` and `Maps.list_object_types/0` context functions
- `Maps.from_db/1` returning string-slug terrain (not atoms)
- The `MapObject.Generic` struct and solidity-based `blocks_movement?` resolution

---

## Concept

A **generative map** is assembled at combat-start from a set of hand-authored **map sections**
stored in the DB. Each section is a fixed-radius hexagonal region with authored tile content.
Sections are placed on a larger hex grid, spaced apart with a 2–3 tile gap, then Wave Function
Collapse fills the gaps with contextually appropriate tiles. Two sections receive special roles:
one gets a **Booster** pickup object (the reward section) and one gets the **spawn point** for
the player's team (the starting section).

Difficulty drives two things: which sections are eligible (sections have a max difficulty level),
and how many sections appear (higher difficulty = larger map).

---

## Vocabulary

| Term | Meaning |
|------|---------|
| **Section** | A DB-stored hexagonal tile region of fixed radius `R` with authored terrain/objects |
| **Terminal section** | A section that connects to only one neighbour after placement (a dead-end) |
| **Leaf section** | Synonym for terminal, used when referring to spawn placement |
| **Section graph** | The adjacency graph built after placement — nodes are sections, edges are neighbours |
| **Gap** | Tiles between placed sections that WFC fills |
| **WFC** | Wave Function Collapse — a constraint-satisfaction tile fill algorithm |
| **Difficulty** | Integer 1–N; sections are tagged `max_difficulty` and filtered at generation time |

---

## Implementation Plan

### 1. `MapSection` schema

**New file:** `lib/game/maps/map_section.ex`

```elixir
defmodule Game.Maps.MapSection do
  use Ecto.Schema
  import Ecto.Changeset

  schema "map_sections" do
    field :slug,           :string
    field :name,           :string
    field :radius,         :integer, default: 4
    field :max_difficulty, :integer, default: 1
    field :tiles,          {:array, :map}, default: []
    field :asset_url,      :string
    timestamps(type: :utc_datetime)
  end

  def changeset(section, attrs) do
    section
    |> cast(attrs, [:slug, :name, :radius, :max_difficulty, :tiles, :asset_url])
    |> validate_required([:slug, :name, :radius, :max_difficulty])
    |> validate_number(:radius, greater_than: 0)
    |> validate_number(:max_difficulty, greater_than: 0)
    |> unique_constraint(:slug)
  end
end
```

`tiles` uses the exact same `{:array, :map}` JSON format as `maps.tiles` — each entry is
`%{"q" => int, "r" => int, "s" => int, "terrain" => slug, "objects" => [...]}`. Coordinates are
**local** to the section centre `{0, 0, 0}`.

**Migration:**

```elixir
create table(:map_sections) do
  add :slug,           :string, null: false
  add :name,           :string, null: false
  add :radius,         :integer, null: false, default: 4
  add :max_difficulty, :integer, null: false, default: 1
  add :tiles,          {:array, :map}, default: []
  add :asset_url,      :string
  timestamps(type: :utc_datetime)
end
create unique_index(:map_sections, [:slug])
```

---

### 2. Context helpers in `Game.Maps`

**File:** `lib/game/maps.ex`

```elixir
def list_sections, do: Repo.all(MapSection)

def list_sections_up_to_difficulty(max) do
  Repo.all(from s in MapSection, where: s.max_difficulty <= ^max)
end

def get_section!(id),         do: Repo.get!(MapSection, id)
def get_section_by_slug(slug), do: Repo.get_by(MapSection, slug: slug)
def create_section(attrs),    do: %MapSection{} |> MapSection.changeset(attrs) |> Repo.insert()
def update_section(%MapSection{} = s, attrs), do: s |> MapSection.changeset(attrs) |> Repo.update()
def delete_section(%MapSection{} = s), do: Repo.delete(s)
```

---

### 3. Admin LiveView — `MapSectionLive`

**New file:** `lib/game_web/live/admin/map_section_live.ex`

Follows the Backpex `LiveResource` pattern identical to `TerrainLive` and `ObjectTypeLive` from
the Map Assets feature. Fields: slug, name, radius, max_difficulty, asset_url. The `tiles` field
is not editable here — sections have their own dedicated tile editor (step 4).

```elixir
defmodule GameWeb.Admin.MapSectionLive do
  use Backpex.LiveResource,
    adapter_config: [
      schema: Game.Maps.MapSection,
      repo: Game.Repo,
      update_changeset: &Game.Maps.MapSection.changeset/2,
      create_changeset: &Game.Maps.MapSection.changeset/2
    ]

  def layout(_), do: {GameWeb.Layouts, :admin}
  def singular_name, do: "Map Section"
  def plural_name, do: "Map Sections"

  def fields do
    [
      slug:           %{module: Backpex.Fields.Text,   label: "Slug", searchable: true},
      name:           %{module: Backpex.Fields.Text,   label: "Name", searchable: true},
      radius:         %{module: Backpex.Fields.Number, label: "Radius"},
      max_difficulty: %{module: Backpex.Fields.Number, label: "Max Difficulty"},
      asset_url:      %{module: Backpex.Fields.Text,   label: "Asset URL"}
    ]
  end

  def item_actions(default_actions) do
    Enum.concat(default_actions,
      edit_tiles: %{module: __MODULE__.EditTilesAction, only: [:row]}
    )
  end

  defmodule EditTilesAction do
    use Backpex.ItemAction
    def icon(assigns, _), do: ~H"<.icon name='hero-map' class='h-4 w-4' />"
    def label(_, _), do: "Edit Tiles"
    def link(%{id: id}, _), do: "/admin/map_sections/#{id}/edit-tiles"
  end
end
```

**Router:**

```elixir
live_resources "/map_sections", Admin.MapSectionLive
live "/map_sections/:id/edit-tiles", Admin.MapSectionEditorLive
```

---

### 4. `MapSectionEditorLive` — tile editor for sections

**New file:** `lib/game_web/live/admin/map_section_editor_live.ex`

This is a thin wrapper around the existing `MapEditorLive` logic. The section editor reuses the
same `GameBoard` component, `build_grid/2`, and tile-click dispatch, but:

- The grid canvas is capped to `section.radius + @editor_padding` — no larger.
- The terrain and object palettes come from `Maps.list_terrains/0` and
  `Maps.list_object_types/0` (same as the map editor after Map Assets).
- There is no Spawn Point tool — sections don't store spawn points (they are assigned at
  generation time).
- Saving calls `Maps.update_section/2` instead of `Maps.update_map/2`.

The section radius is visually indicated by an outer ring of dimmed tiles so the author knows the
boundary.

---

### 5. `Game.MapGenerator` — the generation pipeline

**New file:** `lib/game/map_generator.ex`

This module exposes one public function:

```elixir
defmodule Game.MapGenerator do
  alias Game.{Grid, Maps, Maps.MapSection, Maps.MapTemplate}

  @section_gap 2   # minimum empty tiles between any two section borders
  @booster_object %{"type" => "booster"}

  @doc """
  Generates a MapTemplate procedurally from DB sections filtered by difficulty.
  Returns a fully-formed MapTemplate ready for CombatBuilder.build/2.
  """
  def generate(difficulty) when is_integer(difficulty) and difficulty > 0 do
    sections      = Maps.list_sections_up_to_difficulty(difficulty)
    section_count = section_count_for_difficulty(difficulty)

    chosen = sections |> Enum.shuffle() |> Enum.take(section_count)

    {placed, centres} = place_sections(chosen)
    graph             = build_adjacency_graph(centres, chosen)
    gap_tiles         = wfc_fill(placed, centres, chosen)
    full_tile_map     = Map.merge(placed, gap_tiles)

    {booster_centre, spawn_centre} = pick_terminal_sections(graph, centres)

    tile_map_with_booster = place_booster(full_tile_map, booster_centre, chosen)
    spawn_point           = pick_spawn_in_section(spawn_centre, tile_map_with_booster)

    %MapTemplate{
      name:         "generated_d#{difficulty}",
      display_name: "Generated Map (difficulty #{difficulty})",
      tiles:        tile_map_with_booster,
      spawn_points: %{team_1: spawn_point, team_2: enemy_spawn(tile_map_with_booster, spawn_point)}
    }
  end
```

The function is pure (no side effects) and cacheable. The result is a `MapTemplate` struct that
slots directly into `CombatBuilder.build/2` via its existing `:map` opt.

---

#### 5a. Difficulty → section count

```elixir
# difficulty 1 = 3 sections, +1 per difficulty level
defp section_count_for_difficulty(d), do: 2 + d
```

Chosen sections are sampled without replacement. If fewer sections exist than required, all
available sections are used (no error).

---

#### 5b. Placing sections — `place_sections/1`

Sections are placed at positions on a **meta-grid** — a hex grid where each cell's step size is
`(2 * section_radius + @section_gap + 1)`. This guarantees sections never overlap and always have
at least `@section_gap` empty tiles between their borders.

```elixir
defp place_sections(sections) do
  # One section per meta-cell; meta-cells follow hex coordinates scaled by step_size.
  # step_size = 2 * R + gap + 1 where R = section radius (all sections share the same R
  # per generation run — use the first section's radius as the canonical value).
  r         = hd(sections).radius
  step_size = 2 * r + @section_gap + 1

  # Generate candidate meta-positions outward from origin: (0,0,0), then ring 1, ring 2 …
  meta_positions = stream_hex_positions_outward() |> Enum.take(length(sections))

  # World centre for each section = meta_position * step_size
  centres =
    Enum.zip(sections, meta_positions)
    |> Elixir.Map.new(fn {section, meta} ->
      {section.slug, scale_coord(meta, step_size)}
    end)

  # Blit each section's local tile map into global coordinates
  placed =
    Enum.reduce(sections, %{}, fn section, acc ->
      centre = centres[section.slug]
      section_tiles = section_to_global_tiles(section, centre)
      Map.merge(acc, section_tiles)
    end)

  {placed, centres}
end

# Emits hex positions in outward-ring order: origin, ring-1 (6 tiles), ring-2 (12 tiles) …
defp stream_hex_positions_outward do
  Stream.concat([{0, 0, 0}], Stream.flat_map(Stream.iterate(1, &(&1 + 1)), &hex_ring/1))
end

defp hex_ring(radius) do
  # Standard hex ring algorithm: start at (radius, -radius, 0),
  # walk 6 edges of length `radius`.
  start = {radius, -radius, 0}
  directions = Grid.hex_directions()
  # ... returns the 6*radius positions on the ring at this radius
end

defp scale_coord({q, r, s}, factor), do: {q * factor, r * factor, s * factor}

defp section_to_global_tiles(%MapSection{tiles: tiles}, {cq, cr, cs}) do
  Elixir.Map.new(tiles, fn tile ->
    global_coord = {tile["q"] + cq, tile["r"] + cr, tile["s"] + cs}
    tile_data    = %{terrain: tile["terrain"] || "plain",
                     objects: Maps.deserialize_objects(tile["objects"] || []),
                     occupied_by: nil}
    {global_coord, tile_data}
  end)
end
```

---

#### 5c. Adjacency graph — `build_adjacency_graph/2`

```elixir
# Two sections are adjacent if their centres are within (step_size + 1) of each other.
defp build_adjacency_graph(centres, sections) do
  r         = hd(sections).radius
  step_size = 2 * r + @section_gap + 1
  threshold = step_size + 1

  slugs = Enum.map(sections, & &1.slug)

  for a <- slugs, b <- slugs, a < b,
      Grid.distance(%Grid{}, centres[a], centres[b]) <= threshold,
      into: %{} do
    # Store as adjacency list: slug => [neighbour_slugs]
    {a, [b]}
  end
  |> Enum.reduce(%{}, fn {a, [b]}, acc ->
    acc
    |> Map.update(a, [b], &[b | &1])
    |> Map.update(b, [a], &[a | &1])
  end)
end
```

---

#### 5d. WFC gap fill — `wfc_fill/3`

WFC fills tiles whose coordinates are not in `placed` but fall within the bounding box of the
assembled map.

**Tile set for WFC:** all `MapTerrain` slugs loaded from the DB (via `Maps.list_terrains/0`).

**Constraints (adjacency rules):** a gap tile's terrain must be consistent with its immediate
neighbours. Consistency is defined by a simple ruleset loaded from the DB (see step 6). If no
ruleset exists, WFC falls back to: any terrain adjacent to a section-edge tile must match that
tile's terrain; interior gap tiles can be any terrain.

**Algorithm sketch:**

```elixir
defp wfc_fill(placed, centres, sections) do
  r         = hd(sections).radius
  step_size = 2 * r + @section_gap + 1

  # All coordinates in the bounding hex that are NOT in placed
  outer_radius = (length(sections) |> :math.sqrt() |> ceil()) * step_size + r
  candidates   = all_hex_coords(outer_radius) -- Map.keys(placed)

  # Initialise wave: each candidate cell can be any terrain slug
  terrains   = Maps.list_terrains() |> Enum.map(& &1.slug)
  wave       = Elixir.Map.new(candidates, &{&1, MapSet.new(terrains)})
  adjacency  = load_adjacency_rules()

  collapse_wave(wave, placed, adjacency)
end
```

`collapse_wave/3` runs the standard WFC loop:
1. Find the candidate with fewest remaining possibilities (min-entropy).
2. Pick one terrain at random weighted by frequency (default: uniform).
3. Propagate constraints to all neighbours — remove terrain options that violate adjacency rules.
4. Repeat until all candidates are collapsed.
5. Return `%{coord => tile_data}` for all collapsed gap tiles.

If a contradiction is reached (a cell has 0 options), backtrack one step or restart with a
different seed. For game maps, contradiction is rare — prefer a restart with fresh shuffle.

---

#### 5e. WFC adjacency rule table — `MapTerrainAdjacency`

**New file:** `lib/game/maps/map_terrain_adjacency.ex`

```elixir
defmodule Game.Maps.MapTerrainAdjacency do
  use Ecto.Schema
  import Ecto.Changeset

  schema "map_terrain_adjacencies" do
    field :terrain_a,   :string   # slug
    field :terrain_b,   :string   # slug
    field :weight,      :float, default: 1.0
    timestamps(type: :utc_datetime)
  end

  # Symmetric: if a can be adjacent to b, b can be adjacent to a.
  def changeset(rule, attrs) do
    rule
    |> cast(attrs, [:terrain_a, :terrain_b, :weight])
    |> validate_required([:terrain_a, :terrain_b])
    |> unique_constraint([:terrain_a, :terrain_b])
  end
end
```

A missing row means `terrain_a` and `terrain_b` are **not** allowed as neighbours.
If the table is empty (no rules defined), WFC falls back to "anything can be adjacent to
anything" — a safe default that still produces filled maps.

An admin CRUD live (`MapTerrainAdjacencyLive`) is added under
`/admin/map_terrain_adjacencies` with fields: terrain_a (select), terrain_b (select), weight.

**Migration:**

```elixir
create table(:map_terrain_adjacencies) do
  add :terrain_a, :string, null: false
  add :terrain_b, :string, null: false
  add :weight,    :float, default: 1.0
  timestamps(type: :utc_datetime)
end
create unique_index(:map_terrain_adjacencies, [:terrain_a, :terrain_b])
```

---

#### 5f. Terminal section detection and special object placement

```elixir
# A terminal section has degree 1 in the adjacency graph (only one neighbour).
defp terminal_sections(graph) do
  Enum.filter(graph, fn {_slug, neighbours} -> length(neighbours) == 1 end)
  |> Enum.map(fn {slug, _} -> slug end)
end

defp pick_terminal_sections(graph, centres) do
  terminals = terminal_sections(graph)

  case terminals do
    [_] = one ->
      # Only one terminal: booster goes there, spawn goes to a random other section
      non_terminal = Map.keys(graph) -- one
      [booster_slug] = one
      [spawn_slug]   = Enum.take_random(non_terminal, 1)
      {centres[booster_slug], centres[spawn_slug]}

    [first, second | _rest] ->
      # Pick two distinct terminals; shuffle for randomness
      [booster_slug, spawn_slug] = Enum.take_random([first, second | _rest], 2)
      {centres[booster_slug], centres[spawn_slug]}

    [] ->
      # Fully connected graph (e.g. single section): pick two random sections
      [a, b] = Map.keys(graph) |> Enum.shuffle() |> Enum.take(2)
      {centres[a], centres[b]}
  end
end
```

**Booster placement:**

```elixir
defp place_booster(tile_map, booster_centre, sections) do
  r = hd(sections).radius

  # Find a non-blocked tile near the section centre, preferring the centre itself.
  candidate =
    Grid.tiles_in_range(%Grid{tiles: tile_map}, booster_centre, r)
    |> Enum.reject(&Grid.tile_blocked?(%Grid{tiles: tile_map}, &1))
    |> Enum.min_by(fn coord -> Grid.distance(%Grid{}, coord, booster_centre) end, fn -> booster_centre end)

  Map.update!(tile_map, candidate, fn tile ->
    %{tile | objects: [%MapObject.Booster{} | tile.objects]}
  end)
end
```

**Spawn point placement:**

```elixir
defp pick_spawn_in_section(spawn_centre, tile_map) do
  Grid.tiles_in_range(%Grid{tiles: tile_map}, spawn_centre, 2)
  |> Enum.reject(&Grid.tile_blocked?(%Grid{tiles: tile_map}, &1))
  |> Enum.random()
end

defp enemy_spawn(tile_map, player_spawn) do
  # Place enemies on the opposite side of the map from the player spawn.
  {q, r, s} = player_spawn
  opposite  = {-q, -r, -s}

  Grid.tiles_in_range(%Grid{tiles: tile_map}, opposite, 3)
  |> Enum.reject(&Grid.tile_blocked?(%Grid{tiles: tile_map}, &1))
  |> Enum.min_by(fn coord -> Grid.distance(%Grid{}, coord, opposite) end)
end
```

---

### 6. Integrate with `CombatBuilder`

**File:** `lib/game/combat_builder.ex`

Add a `:difficulty` opt that triggers generation instead of a static map lookup:

```elixir
def build(player_specs, opts \\ []) do
  map_template =
    cond do
      opts[:difficulty] ->
        Game.MapGenerator.generate(opts[:difficulty])
      opts[:map] || get_in(opts[:settings], [:map]) ->
        resolve_map(opts[:map] || get_in(opts[:settings], [:map]))
      true ->
        nil
    end

  # ... rest unchanged
end
```

The caller (e.g. `Game.pick_booster_card` in the shop-to-booster-combat feature) passes
`difficulty: game_state.difficulty` to get a freshly generated map each time.

---

### 7. Caching generated maps (optional but recommended)

`Game.MapGenerator.generate/1` is pure but queries the DB and runs WFC — potentially
10–50 ms. Wrap it in an ETS-backed cache keyed by `{difficulty, :rand_seed}` or simply
pre-generate a pool at application startup:

**File:** `lib/game/map_cache.ex`

```elixir
defmodule Game.MapCache do
  use GenServer

  @pool_size 3  # pre-generate this many maps per difficulty level

  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def get(difficulty) do
    case :ets.lookup(:map_cache, difficulty) do
      [{^difficulty, maps}] ->
        {map, rest} = List.pop_at(maps, :rand.uniform(length(maps)) - 1)
        :ets.insert(:map_cache, {difficulty, rest})
        # Replenish in background
        GenServer.cast(__MODULE__, {:replenish, difficulty})
        map
      [] ->
        # Cold miss: generate synchronously
        Game.MapGenerator.generate(difficulty)
    end
  end

  def init(_) do
    :ets.new(:map_cache, [:named_table, :public, read_concurrency: true])
    {:ok, %{}, {:continue, :warm_up}}
  end

  def handle_continue(:warm_up, state) do
    # Pre-generate maps for difficulties 1–3 at startup
    for d <- 1..3 do
      maps = for _ <- 1..@pool_size, do: Game.MapGenerator.generate(d)
      :ets.insert(:map_cache, {d, maps})
    end
    {:noreply, state}
  end

  def handle_cast({:replenish, difficulty}, state) do
    new_map = Game.MapGenerator.generate(difficulty)
    case :ets.lookup(:map_cache, difficulty) do
      [{^difficulty, maps}] -> :ets.insert(:map_cache, {difficulty, [new_map | maps]})
      [] -> :ets.insert(:map_cache, {difficulty, [new_map]})
    end
    {:noreply, state}
  end
end
```

`CombatBuilder` calls `MapCache.get(difficulty)` instead of calling `MapGenerator` directly.
Add `MapCache` to the application supervision tree.

---

## TDD Plan

### `test/game/maps/map_section_test.exs` (new)

```elixir
describe "MapSection changeset" do
  test "valid with required fields"
  test "slug must be unique"
  test "radius must be positive"
  test "max_difficulty must be positive"
end

describe "Maps.list_sections_up_to_difficulty/1" do
  test "returns sections with max_difficulty <= given value"
  test "excludes sections above the difficulty"
  test "returns empty list when no sections exist"
end
```

### `test/game/map_generator_test.exs` (new)

```elixir
describe "generate/1" do
  test "returns a MapTemplate struct"
  test "map has at least one spawn point"
  test "map has at least one booster object on a non-blocked tile"
  test "section_count_for_difficulty: difficulty 1 yields 3 sections, difficulty 3 yields 5"
  test "generated tiles are all connected (no isolated islands)"
  test "sections do not overlap — no coordinate appears twice from two different sections"
  test "gap between any two section borders is >= @section_gap tiles"
end

describe "place_sections/1" do
  test "each section's tiles appear in the output at correct global offsets"
  test "section centres are on valid hex coordinates (q+r+s == 0)"
end

describe "terminal section detection" do
  test "a section with one neighbour is terminal"
  test "a section with two or more neighbours is not terminal"
  test "single-section map: both booster and spawn end up in the only section"
end

describe "wfc_fill/3" do
  test "all gap coordinates receive a terrain slug"
  test "no gap tile has a terrain that violates adjacency rules with its neighbours"
  test "returns empty map when there are no gaps"
end
```

### `test/game_web/live/admin/map_section_live_test.exs` (new)

```elixir
describe "MapSectionLive" do
  test "lists section records"
  test "creates a new section via form"
  test "edit-tiles link navigates to section editor"
end
```

### `test/game_web/live/admin/map_section_editor_live_test.exs` (new)

```elixir
describe "MapSectionEditorLive" do
  test "renders hex grid capped to section radius + padding"
  test "terrain palette loads from DB"
  test "painting a tile updates pending_tiles"
  test "save persists to MapSection record"
  test "no Spawn Point tool is visible"
end
```

### `test/game/combat_builder_test.exs` — extend

```elixir
describe "build with :difficulty opt" do
  test "calls MapGenerator.generate/1 with the given difficulty"
  test "resulting CombatState has a non-empty grid"
  test "spawn positions come from the generated map's spawn_points"
end
```

---

## Critical Files

| File | Change |
|------|--------|
| `lib/game/maps/map_section.ex` | **New** — `MapSection` Ecto schema |
| `lib/game/maps/map_terrain_adjacency.ex` | **New** — `MapTerrainAdjacency` Ecto schema for WFC rules |
| `priv/repo/migrations/<ts>_create_map_sections.exs` | **New** — `map_sections` table |
| `priv/repo/migrations/<ts>_create_map_terrain_adjacencies.exs` | **New** — `map_terrain_adjacencies` table |
| `lib/game/maps.ex` | Add CRUD for `MapSection` and `MapTerrainAdjacency`; add `list_sections_up_to_difficulty/1` |
| `lib/game/map_generator.ex` | **New** — full generation pipeline: section placement, adjacency graph, WFC, booster/spawn placement |
| `lib/game/map_cache.ex` | **New** — ETS-backed pre-generation pool, GenServer |
| `lib/game_web/live/admin/map_section_live.ex` | **New** — Backpex admin for sections |
| `lib/game_web/live/admin/map_section_editor_live.ex` | **New** — tile editor for sections (mirrors MapEditorLive) |
| `lib/game_web/live/admin/map_terrain_adjacency_live.ex` | **New** — Backpex admin for WFC rules |
| `lib/game_web/router.ex` | Add routes for all three new admin lives |
| `lib/game/combat_builder.ex` | Add `:difficulty` opt; call `MapCache.get/1` when present |
| `lib/game/application.ex` | Add `MapCache` to supervision tree |

---

## Verification

1. Create two `MapSection` records in the admin (each with radius 4, max_difficulty 1). Paint
   tiles into each using the section editor.
2. Define at least one `MapTerrainAdjacency` rule (e.g. `plain` ↔ `plain`).
3. In `iex -S mix`, call `Game.MapGenerator.generate(1)` — inspect the returned `MapTemplate`.
   Confirm: two sections of tiles are present at distinct centres, a gap region exists between
   them, a `Booster` object is somewhere in a terminal section, and `spawn_points` is non-empty.
4. Start a combat using `CombatBuilder.build(specs, difficulty: 1)` — confirm the grid loads and
   characters spawn correctly.
5. Increase difficulty to 3, call `generate(3)` — confirm 5 sections are placed and the map is
   larger.
6. Restart the app — confirm `MapCache` pre-generates maps and subsequent calls return instantly.
