# Content Cache Agent

## Problem

Every time a lobby loads a class — during character selection, combat setup, or anything else
that calls `Content.get_base_class_by_class!/1` — Ecto fires three queries: one for the
`BaseClass` row, one for its `BaseDeck` + `BaseDeckCard` join records, and one for each
`BaseCard`. `BaseDeck.get_cards/1` then converts every row through `base_card_to_card/1`.
None of this content changes at runtime except when an admin saves. An in-memory Agent is
the right fit: cheap reads, simple invalidation, same pattern already used by `Game.CombatSaves`.

---

## Architecture

### New module: `Game.ContentCache`

A named Agent holding a map of `class_name → preloaded BaseClass struct` (with deck and
cards already fully preloaded):

```
%{
  "warrior"  => %BaseClass{deck: %BaseDeck{base_deck_cards: [...], cards: [...]}, ...},
  "mage"     => %BaseClass{...},
  ...
}
```

The cards inside are the raw `BaseCard` structs (not yet converted to `Game.Card`). The
`base_card_to_card` conversion still happens at character instantiation time because
`BaseDeck.get_cards/1` assigns per-instance sequential IDs — those must remain dynamic.
What we eliminate is the database round-trip.

---

## Implementation Steps

### 1. Create `lib/game/content_cache.ex`

```elixir
defmodule Game.ContentCache do
  use Agent

  alias Game.{Repo, Content}
  alias Game.Content.BaseClass

  def start_link(_opts) do
    Agent.start_link(&load_all/0, name: __MODULE__)
  end

  # --- Public API ---

  def get(class_name) do
    Agent.get(__MODULE__, &Map.get(&1, normalize(class_name)))
  end

  def get!(class_name) do
    case get(class_name) do
      nil ->
        bc = fetch_one(class_name)
        Agent.update(__MODULE__, &Map.put(&1, normalize(class_name), bc))
        bc
      bc ->
        bc
    end
  end

  def all, do: Agent.get(__MODULE__, & &1)

  def reload(class_name) do
    bc = fetch_one(class_name)
    Agent.update(__MODULE__, &Map.put(&1, normalize(class_name), bc))
    bc
  end

  def reload_all do
    Agent.update(__MODULE__, fn _ -> load_all() end)
  end

  # --- Private ---

  defp load_all do
    Repo.all(BaseClass)
    |> Repo.preload(deck: [base_deck_cards: [:card]], strategy: [tactics: []])
    |> Map.new(&{normalize(&1.class), &1})
  end

  defp fetch_one(class_name) do
    Content.get_base_class_by_class!(class_name)
    # get_base_class_by_class! already preloads deck: [:cards], strategy: []
    # Update that function to also preload base_deck_cards for consistency (see step 3)
  end

  defp normalize(name), do: String.downcase(name)
end
```

Key choices:
- State is keyed by **lowercase class name** (matches the existing case-insensitive lookup).
- `get!/1` is self-healing on a miss: it fetches from the DB, populates the entry, and returns
  the result — degrading gracefully to the old behavior instead of crashing.
- `reload/1` fetches a single class — called after an admin save.
- `reload_all/0` replaces the entire map — useful for dev resets or data migrations.
- `base_deck_cards: [:card]` preloads the join table with the nested `BaseCard` records,
  which is what `BaseDeck.get_cards/1` expects.

### 2. Register in `lib/game/application.ex`

Add `Game.ContentCache` to the supervisor children list, **after `Game.Repo`** (it reads from
the database on startup) and **before `Game.CombatSaves`**:

```elixir
children = [
  GameWeb.Telemetry,
  Game.Repo,
  {DNSCluster, query: Application.get_env(:game, :dns_cluster_query) || :ignore},
  {Phoenix.PubSub, name: Game.PubSub},
  Game.ContentCache,        # <-- add here
  Game.CombatSaves,
  {Registry, keys: :unique, name: Game.LobbyRegistry},
  {DynamicSupervisor, strategy: :one_for_one, name: Game.LobbySupervisor},
  GameWeb.Endpoint
]
```

### 3. Update `Game.Content.get_base_class_by_class!/1`

Replace the database-hitting function with a cache read:

```elixir
# Before
def get_base_class_by_class!(class) do
  BaseClass
  |> where([bc], fragment("lower(?)", bc.class) == fragment("lower(?)", ^class))
  |> Repo.one!()
  |> Repo.preload(deck: [:cards], strategy: [])
end

# After
def get_base_class_by_class!(class) do
  Game.ContentCache.get!(class)
end
```

Callers (`CombatBuilder`, `Character.from_character_data/1`, lobby logic) keep calling the
same function — no changes needed there.

### 4. Update `list_base_classes/0` and `list_playable_classes/0`

```elixir
def list_base_classes do
  Game.ContentCache.all() |> Map.values()
end

def list_playable_classes do
  Game.ContentCache.all()
  |> Map.values()
  |> Enum.filter(&is_nil(&1.strategy_id))
end
```

### 5. Invalidate on admin save

In each Backpex admin LiveView, add an `after_save` hook that calls `ContentCache.reload/1`
(or `reload_all/0` for simplicity).

**`base_class_live.ex`** — after Backpex commits the changeset:

```elixir
@impl Backpex.LiveResource
def on_item_updated(item, _socket) do
  Game.ContentCache.reload(item.class)
  {:ok, item}
end

@impl Backpex.LiveResource
def on_item_created(item, _socket) do
  Game.ContentCache.reload(item.class)
  {:ok, item}
end
```

**`base_deck_live.ex`** and **`base_card_live.ex`** — a deck or card change affects every
class that references it. Use `reload_all/0` here since the relation is many-to-many and
tracking which class owns the deck is extra complexity:

```elixir
@impl Backpex.LiveResource
def on_item_updated(_item, socket) do
  Game.ContentCache.reload_all()
  {:ok, socket}
end
```

Check the exact callback name Backpex exposes (`on_item_updated`, `after_save`,
`handle_event("save", ...)`) and hook into whichever fires post-persist.

**`strategy_live.ex`** — same pattern as base_deck_live, `reload_all/0`.

---

## Preload Shape Alignment

`BaseDeck.get_cards/1` expects `base_deck_cards` to be a list of `%BaseDeckCard{card: %BaseCard{}, count: N}`.
The current `get_base_class_by_class!/1` preloads `deck: [:cards]`, which loads the `cards`
through-association (flat list, no counts). Verify that `ContentCache.load_all/0` uses
`deck: [base_deck_cards: [:card]]` so that `get_cards/1` gets the join records with counts
intact. If `get_base_class_by_class!/1` currently receives the wrong shape, fix `get_cards/1`
to also accept the through-association form, or standardize on one preload shape.

---

## What Does Not Change

- `BaseDeck.get_cards/1` and `base_card_to_card/1` — still run per-character-instantiation.
  Card IDs (0, 1, 2…) are instance-specific.
- `Game.CombatSaves` — unchanged.
- `CombatBuilder.build/2` — unchanged; it calls `Content.get_base_class_by_class!/1` which
  now hits the cache.
- All combat mechanics — untouched.

---

## Failure Modes & Notes

- **Startup failure**: if the DB is unreachable when the Agent starts, the supervisor will
  fail to start. This is acceptable — the same thing happens today if the Repo can't connect.
- **Cache misses**: `get!/1` falls back to the DB and self-populates on a miss, so the
  system never hard-crashes due to a missing entry. This covers: new classes added via
  seeds/migrations/iex, a Backpex callback that silently misfires, or a crash between a DB
  write and the `reload` call. The miss is logged implicitly by the extra DB query — consider
  adding a `Logger.warning/1` in the nil branch to make misses visible in production.
- **Stale cache**: the only write path is the admin UI. As long as every admin save calls
  `reload/1` or `reload_all/0`, the cache is always current. There is no TTL because content
  only changes via deliberate admin action.
- **Multi-node**: this Agent is local to one BEAM node. If the game ever runs multi-node,
  replace with a distributed ETS table or a PubSub-driven invalidation strategy. For now,
  single-node is assumed.
- **Memory**: each `BaseClass` struct with a preloaded deck and ~30 cards is small (a few KB).
  Even with 50 classes the footprint is negligible.
