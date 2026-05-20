# Feature: Universes

## Context

A **universe** is a self-contained game definition: a named collection of cards, decks, character
classes, and strategies that together implement one variant of the game. Multiple universes can
coexist in the same database (e.g. a fantasy universe and a sci-fi universe).

Currently all content is global and flat — cards, decks, classes, and strategies share a single
namespace with no grouping. This feature adds a `Universe` entity and associates all content to it.

---

## Data Model

### New table: `universes`

```
id          serial primary key
name        string, not null, unique
description string
inserted_at, updated_at
```

### Foreign key additions

Add a nullable `universe_id` (FK → universes, on_delete: nilify_all) to:

| Table | Schema |
|-------|--------|
| `cards` | `Game.BaseCards.BaseCard` |
| `decks` | `Game.BaseDecks.BaseDeck` |
| `base_classes` | `Game.Content.BaseClass` |
| `strategies` | `Game.Content.Strategy` |

`FormulaAlias` is formula/calculation infrastructure shared across universes — do **not** add
`universe_id` there.

Nullable so existing content is not broken before migration.

---

## Implementation Plan

### 1. Universe schema

**New file:** `lib/game/content/universe.ex`

```elixir
defmodule Game.Content.Universe do
  use Ecto.Schema
  import Ecto.Changeset

  schema "universes" do
    field :name, :string
    field :description, :string

    has_many :base_classes, Game.Content.BaseClass
    has_many :decks, Game.BaseDecks.BaseDeck
    has_many :cards, Game.BaseCards.BaseCard
    has_many :strategies, Game.Content.Strategy

    timestamps(type: :utc_datetime)
  end

  def changeset(universe, attrs) do
    universe
    |> cast(attrs, [:name, :description])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
```

### 2. Migration: create universes table + add universe_id FKs

**New migration:**

```elixir
def change do
  create table(:universes) do
    add :name, :string, null: false
    add :description, :string
    timestamps(type: :utc_datetime)
  end

  create unique_index(:universes, [:name])

  alter table(:cards) do
    add :universe_id, references(:universes, on_delete: :nilify_all)
  end

  alter table(:decks) do
    add :universe_id, references(:universes, on_delete: :nilify_all)
  end

  alter table(:base_classes) do
    add :universe_id, references(:universes, on_delete: :nilify_all)
  end

  alter table(:strategies) do
    add :universe_id, references(:universes, on_delete: :nilify_all)
  end

  create index(:cards, [:universe_id])
  create index(:decks, [:universe_id])
  create index(:base_classes, [:universe_id])
  create index(:strategies, [:universe_id])
end
```

### 3. Update existing schemas to include universe_id

**Files:**
- `lib/game/base_cards/base_card.ex`
- `lib/game/base_decks/base_deck.ex`
- `lib/game/content/base_class.ex`
- `lib/game/content/strategy.ex`

Add to each schema:
```elixir
belongs_to :universe, Game.Content.Universe
```

Add `:universe_id` to the `cast` list in each changeset. Leave it optional (no `validate_required`).

### 4. Context module

**New file:** `lib/game/content/universes.ex` (or add to `lib/game/content.ex`)

```elixir
defmodule Game.Universes do
  import Ecto.Query
  alias Game.Repo
  alias Game.Content.Universe

  def list_universes, do: Repo.all(Universe)

  def get_universe!(id), do: Repo.get!(Universe, id)

  def create_universe(attrs), do: %Universe{} |> Universe.changeset(attrs) |> Repo.insert()

  def update_universe(universe, attrs), do: universe |> Universe.changeset(attrs) |> Repo.update()

  def delete_universe(universe), do: Repo.delete(universe)

  def list_classes_for_universe(universe_id) do
    Game.Repo.all(from bc in Game.Content.BaseClass, where: bc.universe_id == ^universe_id,
      preload: [:deck, :strategy])
  end
end
```

### 5. Admin interface

**New file:** `lib/game_web/live/admin/universe_live.ex`

Use Backpex.LiveResource (same pattern as `base_card_live.ex`, `base_class_live.ex`) with fields:
- `name` (text, searchable)
- `description` (text)

Add a route in the router under the existing `/admin` scope.

Extend the existing admin LiveViews for BaseCard, BaseDeck, BaseClass, and Strategy to include a
`universe` BelongsTo field (same pattern as the `deck` BelongsTo field in `base_class_live.ex`).

### 6. Content loading: scope by universe

In `lib/game/content.ex`, add universe-scoped query helpers:

```elixir
def list_playable_classes_for_universe(universe_id) do
  Repo.all(
    from bc in BaseClass,
    where: bc.universe_id == ^universe_id and is_nil(bc.strategy_id),
    preload: [deck: [:cards], strategy: []]
  )
end
```

The existing `list_playable_classes/0` (no universe filter) can stay for backwards compatibility
until all call sites are updated.

### 7. Update push_content_sync

**File:** `lib/mix/tasks/game.push_content_sync.ex`

Add sync of the `universes` table (before cards/decks/classes, since they FK to it):

```elixir
local_universes = Game.Repo.all(Universe)

Game.ProdRepo.delete_all(BaseClass)
Game.ProdRepo.delete_all(BaseDeckCard)
Game.ProdRepo.delete_all(BaseDeck)
Game.ProdRepo.delete_all(BaseCard)
Game.ProdRepo.delete_all(Strategy)
Game.ProdRepo.delete_all(FormulaAlias)
Game.ProdRepo.delete_all(GameMap)
Game.ProdRepo.delete_all(Universe)   # add this

# Build universe_id_map like existing id maps:
universe_id_map =
  Enum.reduce(local_universes, %{}, fn u, acc ->
    prod = %Universe{} |> Universe.changeset(%{name: u.name, description: u.description})
           |> Game.ProdRepo.insert!()
    Map.put(acc, u.id, prod.id)
  end)

# When inserting cards/decks/classes/strategies, map universe_id:
%{..., universe_id: u.universe_id && Map.fetch!(universe_id_map, u.universe_id)}
```

---

## Critical Files

| File | Change |
|------|--------|
| `lib/game/content/universe.ex` | New schema |
| `priv/repo/migrations/<ts>_create_universes.exs` | New migration |
| `lib/game/base_cards/base_card.ex` | Add `belongs_to :universe` + `universe_id` in changeset |
| `lib/game/base_decks/base_deck.ex` | Add `belongs_to :universe` + `universe_id` in changeset |
| `lib/game/content/base_class.ex` | Add `belongs_to :universe` + `universe_id` in changeset |
| `lib/game/content/strategy.ex` | Add `belongs_to :universe` + `universe_id` in changeset |
| `lib/game/universes.ex` | New context module |
| `lib/game_web/live/admin/universe_live.ex` | New Backpex admin resource |
| `lib/game_web/live/admin/base_card_live.ex` | Add universe BelongsTo field |
| `lib/game_web/live/admin/base_deck_live.ex` | Add universe BelongsTo field |
| `lib/game_web/live/admin/base_class_live.ex` | Add universe BelongsTo field |
| `lib/game_web/live/admin/strategy_live.ex` | Add universe BelongsTo field |
| `lib/game/content.ex` | Add `list_playable_classes_for_universe/1` |
| `lib/mix/tasks/game.push_content_sync.ex` | Sync universes + map universe_id on all entities |
| Router | Add universe admin route |

---

## Verification

1. Run `mix ecto.migrate` — confirm no errors.
2. Visit `/admin/universes` — create a universe named "Base Game".
3. Open a card in `/admin/cards` — confirm a "Universe" select field appears; assign it to "Base Game".
4. Assign several decks and classes to the same universe.
5. Run `mix game.push_content_sync` (with `PROD_DATABASE_URL` pointing to a test DB) — confirm the universe row and universe_id FK values are correctly propagated to prod.
6. Query `Game.Universes.list_classes_for_universe(id)` in IEx — confirm only the assigned classes are returned.
