# Feature: push_content_sync Should Use insert_all

## Context

`Mix.Tasks.Game.PushContentSync` (`lib/mix/tasks/game.push_content_sync.ex`) syncs local content
(cards, decks, classes, strategies, formula aliases, maps) to a production database. Currently it
runs one `ProdRepo.insert!` per record inside `Enum.reduce`/`Enum.each` loops — O(N) round trips.

Switching to `Repo.insert_all` reduces this to one query per entity type, which matters when the
content catalogue grows.

---

## Implementation Plan

### Constraints

Four entity types need their new prod IDs for subsequent foreign-key inserts:
- `FormulaAlias` → its IDs are not referenced by others here (no FK consumers in this task).
- `Strategy` → ID referenced by `BaseClass.strategy_id`.
- `BaseCard` → ID referenced by `BaseDeckCard.card_id`.
- `BaseDeck` → ID referenced by `BaseDeckCard.deck_id` and `BaseClass.deck_id`.

`Repo.insert_all` with `returning: [:id]` gives back the new IDs in the same order the rows were
passed. We can pair them with the local items by position to build the ID maps.

`BaseDeckCard`, `GameMap`, and `BaseClass` have no downstream FK consumers and need no ID map.

### Changes

**File:** `lib/mix/tasks/game.push_content_sync.ex`

Replace each `Enum.reduce`/`Enum.each` insert loop with a batched `insert_all` + `returning: [:id]`
call. Use `Repo.insert_all/3` (third arg: opts).

`insert_all` does not run changesets, so we build plain attribute maps directly (the changeset logic
here only validates — all values come from already-validated local structs, so skipping changeset
is safe).

```elixir
# FormulaAlias — no ID map needed (nothing references it here)
formula_alias_rows = Enum.map(local_formula_aliases, fn fa ->
  %{name: fa.name, expression: fa.expression, description: fa.description}
end)
Game.ProdRepo.insert_all(FormulaAlias, formula_alias_rows)

# Strategy — build ID map from returned IDs
strategy_rows = Enum.map(local_strategies, fn s ->
  tactics_json = Jason.encode!(Enum.map(s.tactics, &Map.take(&1, [:trigger, :action, :card_filter])))
  %{name: s.name, tactics: tactics_json}   # adjust field type as needed — see note below
end)
{_count, prod_strategies} = Game.ProdRepo.insert_all(Strategy, strategy_rows, returning: [:id])
strategy_id_map = Map.new(Enum.zip(local_strategies, prod_strategies), fn {local, prod} ->
  {local.id, prod.id}
end)

# BaseCard — build ID map from returned IDs
card_rows = Enum.map(local_cards, fn c ->
  %{
    name: c.name,
    ap: c.ap,
    range: c.range,
    headline: c.headline,
    rarity: c.rarity,
    targeting: c.targeting,
    effects: c.effects  # stored as jsonb — pass raw value from local
  }
end)
{_count, prod_cards} = Game.ProdRepo.insert_all(BaseCard, card_rows, returning: [:id])
card_id_map = Map.new(Enum.zip(local_cards, prod_cards), fn {local, prod} ->
  {local.id, prod.id}
end)

# BaseDeck — build ID map from returned IDs
deck_rows = Enum.map(local_decks, fn d -> %{name: d.name} end)
{_count, prod_decks} = Game.ProdRepo.insert_all(BaseDeck, deck_rows, returning: [:id])
deck_id_map = Map.new(Enum.zip(local_decks, prod_decks), fn {local, prod} ->
  {local.id, prod.id}
end)

# BaseDeckCard — no ID map needed
deck_card_rows = Enum.map(local_deck_cards, fn bdc ->
  %{
    count: bdc.count,
    card_id: Map.fetch!(card_id_map, bdc.card_id),
    deck_id: Map.fetch!(deck_id_map, bdc.deck_id)
  }
end)
Game.ProdRepo.insert_all(BaseDeckCard, deck_card_rows)

# GameMap — no ID map needed
map_rows = Enum.map(local_maps, fn m ->
  %{slug: m.slug, display_name: m.display_name, tiles: m.tiles, spawn_points: m.spawn_points}
end)
Game.ProdRepo.insert_all(GameMap, map_rows)

# BaseClass — no ID map needed
class_rows = Enum.map(local_classes, fn cls ->
  %{
    class: cls.class,
    avatar_url: cls.avatar_url,
    base_hp: cls.base_hp,
    base_ap: cls.base_ap,
    base_movement: cls.base_movement,
    deck_id: cls.deck_id && Map.fetch!(deck_id_map, cls.deck_id),
    strategy_id: cls.strategy_id && Map.fetch!(strategy_id_map, cls.strategy_id)
  }
end)
Game.ProdRepo.insert_all(BaseClass, class_rows)
```

**Note on embedded/jsonb fields (`tactics`, `effects`, `targeting`, `tiles`, `spawn_points`):**
`insert_all` does not run Ecto type casts. For jsonb columns Ecto normally handles encoding via the
changeset, but `insert_all` accepts raw Elixir maps/lists and Postgrex encodes them correctly as
long as the column type is `:map` or `{:array, :map}`. Verify by checking the migration column
types. If any embedded field is stored as a custom type (e.g., embedded_schema), you may need to
call `Jason.encode!/1` and pass the result as a plain string, or use `Ecto.Type.dump!/2` — check
the schema definitions before assuming raw pass-through works.

---

## Critical Files

| File | Change |
|------|--------|
| `lib/mix/tasks/game.push_content_sync.ex` | Replace all `Enum.reduce`/`Enum.each` insert loops with `insert_all` calls |

---

## Verification

1. Set `PROD_DATABASE_URL` to a test database (not actual prod).
2. Run `mix game.push_content_sync`.
3. Confirm the output counts match what was read ("Found: X cards…").
4. Query the test prod database and verify all rows exist with correct FK relationships
   (deck_cards reference valid card/deck IDs, classes reference valid deck/strategy IDs).
5. Run a second time — confirm delete-then-insert is idempotent and the counts stay the same.
