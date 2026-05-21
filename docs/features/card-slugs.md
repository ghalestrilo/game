# Feature: Card Slugs as Stable Identity

## Context

`Give` card effect stores a `card_id` integer to look up a `BaseCard` at runtime
(`Game.BaseCards.get_base_card!(card_id)`). Integer IDs are auto-incremented per database, so
syncing cards between environments (push/pull_content_sync) can reassign them — a card configured
in a `Give` effect on dev silently breaks on prod because the ID no longer matches the same card.

The fix: add a `slug` field (unique, auto-derived from `name` via the `slugify` library) and use
it as the stable lookup key. Pattern taken from `notabc/imazon` — `Imazon.Content.Post` does
exactly this.

---

## Implementation Plan

### 1. Add dependency

**`mix.exs`**:
```elixir
{:slugify, "~> 1.3"}
```

### 2. Migration

Three steps in one migration (`up/0` only — use `up`/`down` instead of `change` because the
back-fill + `null: false` tightening can't be expressed with `change`):

```elixir
def up do
  alter table(:cards) do
    add :slug, :string           # nullable to allow back-fill
  end

  # Back-fill using a window function to de-duplicate collisions.
  # Cards with the same base slug get -2, -3, ... appended (first occurrence keeps the plain slug).
  # Discovered in dev: two cards both named "Phase" — this handles that case generically.
  execute """
  UPDATE cards
  SET slug = sub.final_slug
  FROM (
    SELECT
      id,
      CASE
        WHEN row_number() OVER (PARTITION BY base_slug ORDER BY id) = 1
        THEN base_slug
        ELSE base_slug || '-' || row_number() OVER (PARTITION BY base_slug ORDER BY id)
      END AS final_slug
    FROM (
      SELECT id,
        lower(trim(both '-' from regexp_replace(name, '[^a-zA-Z0-9]+', '-', 'g'))) AS base_slug
      FROM cards
    ) slugged
  ) sub
  WHERE cards.id = sub.id
  """

  alter table(:cards) do
    modify :slug, :string, null: false
  end

  create unique_index(:cards, [:slug])
end

def down do
  drop unique_index(:cards, [:slug])
  alter table(:cards) do
    remove :slug
  end
end
```

> **Note:** The plain SQL back-fill intentionally mirrors what `Slug.slugify/1` produces for
> ASCII names. For non-ASCII card names, the Elixir changeset's `put_slug` will produce the
> correct unicode-aware slug going forward; back-filling those is rare and can be handled manually.

### 3. BaseCard schema + changeset

**`lib/game/base_cards/base_card.ex`** — copy the imazon `put_slug` pattern exactly:

```elixir
alias Slug   # add at top

schema "cards" do
  field :slug, :string
  # ... existing fields unchanged
end

def changeset(base_card, attrs) do
  base_card
  |> cast(attrs, [:name, :ap, :range, :headline, :rarity, :targeting, :slug])
  |> cast_embed(:effects, ...)
  |> validate_required([:name, :ap, :headline, :rarity])
  |> put_slug()
  |> unique_constraint(:slug)
end

defp put_slug(changeset) do
  case {get_change(changeset, :slug), get_change(changeset, :name)} do
    {nil, name} when is_binary(name) -> put_change(changeset, :slug, Slug.slugify(name))
    _ -> changeset
  end
end
```

Slug is computed from name on create; passing an explicit `:slug` attr overrides (allows manual
correction of collisions like the two "Phase" cards).

### 4. BaseCards context

**`lib/game/base_cards.ex`** — add slug lookup:

```elixir
def get_base_card_by_slug!(slug), do: Repo.get_by!(BaseCard, slug: slug)
```

### 5. Give effect — switch `card` field to slug string

**`lib/game/combat/card_effects/give.ex`**:

```elixir
# card is now a slug string, e.g. "fireball"
def process(%Give{card: slug, pile: pile}, target, combat_state)
    when is_binary(slug) do
  base_card = Game.BaseCards.get_base_card_by_slug!(slug)
  game_card  = base_card_to_card(base_card)
  updated_target = %{target | cards: Map.update!(target.cards, pile_to_atom(pile), &[game_card | &1])}
  CombatState.update_target(combat_state, target, updated_target)
end

def process(%Give{}, _target, combat_state), do: combat_state
```

### 6. Admin card select — use slug as option value

**`lib/game_web/live/admin/fields/effect_field.ex`** — `param == "card"` branch:

```heex
<option value={base_card.slug} selected={base_card.slug == Map.get(@value_map, "card", "")}>
  {base_card.name}
</option>
```

### 7. Sync tasks — simplify card_id_map

**`lib/mix/tasks/game.push_content_sync.ex`** and **`game.pull_content_sync.ex`**

After inserting cards into prod, build the ID map by looking up each card by slug (stable across
environments) instead of tracking local→prod ID mappings through the insert loop:

```elixir
card_id_map = Map.new(local_cards, fn local_card ->
  prod_card = Game.ProdRepo.get_by!(BaseCard, slug: local_card.slug)
  {local_card.id, prod_card.id}
end)
```

`BaseDeckCard` still uses integer FKs internally — that's fine. The slug just replaces the
brittle insert-order tracking.

---

## Critical Files

| File | Change |
|------|--------|
| `mix.exs` | Add `{:slugify, "~> 1.3"}` |
| `priv/repo/migrations/<ts>_add_slug_to_cards.exs` | Add column, window-function back-fill (handles duplicates), tighten to `null: false`, unique index |
| `lib/game/base_cards/base_card.ex` | Add `slug` field, `put_slug/1` changeset helper, `unique_constraint` |
| `lib/game/base_cards.ex` | Add `get_base_card_by_slug!/1` |
| `lib/game/combat/card_effects/give.ex` | Switch `card` from integer to slug; update guard + lookup |
| `lib/game_web/live/admin/fields/effect_field.ex` | Use `base_card.slug` as option value |
| `lib/mix/tasks/game.push_content_sync.ex` | Replace reduce-based `card_id_map` with slug lookup |
| `lib/mix/tasks/game.pull_content_sync.ex` | Same |

---

## Verification

1. `mix deps.get && mix ecto.migrate` — confirm slug column, all existing cards have non-null slugs, no duplicates.
2. `Game.BaseCards.list_basecards() |> Enum.map(& &1.slug)` in IEx — no nils, no duplicates.
3. Create a card via admin — confirm slug auto-generated from name.
4. Rename a card via admin — confirm slug does **not** change (only computed on create, not on update, so existing Give effects keep working).
5. Create a Give-effect card referencing a slug. Play it in sandbox — target receives the card.
6. Run sync task against a test DB; manually corrupt card integer IDs; re-run — Give effect still resolves correctly via slug.
