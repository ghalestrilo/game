# Feature: Card Classes and Map Boosters

## Context

When a player walks over a booster pickup on the map, it triggers a class selection modal (player's
own class + 2 random others), and the resulting booster pack is drawn from that chosen class's
booster pool.

Boosters already exist as a pre-combat draft mechanic (lobby phase). This feature adds an in-game
booster pickup triggered by map exploration.

---

## Data Design

Booster pools mirror the existing deck pattern: a `BoosterPool` entity owns a list of cards via a
`booster_pool_cards` join table (analogous to `base_deck_cards`). Each `BaseClass` gets a nullable
`booster_pool_id` FK pointing to its pool.

**Why not a `:class` string field on `BaseCard`?**
- One class per card — cards can't appear in multiple class pools without duplication.
- No probability weighting — the join table's `count` field lets you weight a card's appearance
  frequency, matching how decks already work.
- Fragile coupling — renaming a class would require auditing all card records.
- The join table approach is already proven in this codebase and the admin UI pattern is identical.

A card that should appear in all class pools is simply added to each pool. A "class-agnostic" card
has no special status — it is curated explicitly per pool.

---

## Implementation Plan

### 1. Create `BoosterPool` and `booster_pool_cards`

**New file:** `lib/game/content/booster_pool.ex`

```elixir
defmodule Game.Content.BoosterPool do
  use Ecto.Schema
  import Ecto.Changeset

  schema "booster_pools" do
    field :name, :string
    has_many :booster_pool_cards, Game.Content.BoosterPoolCard
    has_many :cards, through: [:booster_pool_cards, :card]
    timestamps()
  end

  def changeset(pool, attrs) do
    pool
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
```

**New file:** `lib/game/content/booster_pool_card.ex`

```elixir
defmodule Game.Content.BoosterPoolCard do
  use Ecto.Schema
  import Ecto.Changeset

  schema "booster_pool_cards" do
    field :count, :integer, default: 1
    belongs_to :pool, Game.Content.BoosterPool
    belongs_to :card, Game.BaseCards.BaseCard
  end

  def changeset(bpc, attrs) do
    bpc
    |> cast(attrs, [:count, :pool_id, :card_id])
    |> validate_required([:pool_id, :card_id])
    |> unique_constraint([:pool_id, :card_id])
  end
end
```

**Migrations:**

```elixir
# create_booster_pools
create table(:booster_pools) do
  add :name, :string, null: false
  timestamps()
end
create unique_index(:booster_pools, [:name])

# create_booster_pool_cards
create table(:booster_pool_cards) do
  add :count, :integer, null: false, default: 1
  add :pool_id, references(:booster_pools, on_delete: :delete_all), null: false
  add :card_id, references(:cards, on_delete: :delete_all), null: false
end
create unique_index(:booster_pool_cards, [:pool_id, :card_id])

# add_booster_pool_id_to_base_classes
alter table(:base_classes) do
  add :booster_pool_id, references(:booster_pools, on_delete: :nilify_all)
end
```

### 2. Update `BaseClass`

**File:** `lib/game/content/base_class.ex`

Add the association:

```elixir
belongs_to :booster_pool, Game.Content.BoosterPool
```

Add `:booster_pool_id` to the `cast` list in `changeset/2`.

### 3. Admin UI

**File:** `lib/game_web/live/admin/base_class_live.ex` (or equivalent)

Add a booster pool selector to the class admin form (BelongsTo-style select, same pattern as the
deck selector on BaseClass).

Add a `BoosterPool` admin page (clone of the BaseDeck admin) so pools and their cards can be
managed.

### 4. Create the Booster map object

**New file:** `lib/game/map_objects/booster.ex`

```elixir
defmodule Game.MapObject.Booster do
  defstruct []

  defimpl Game.MapObject do
    def blocks_movement?(_), do: false

    def on_enter(_booster, _character, combat_state) do
      {:booster_pickup, combat_state}
    end
  end
end
```

Returns `{:booster_pickup, combat_state}` — a new return variant that signals the game loop to
trigger a class selection flow.

### 5. Handle `{:booster_pickup}` in combat entry effects

**File:** `lib/game/combat.ex` — `apply_entry_effects/3`

Extend the pattern match to handle the new return:

```elixir
defp apply_entry_effects(%CombatState{grid: grid} = combat, character, position) do
  objects = get_in(grid.tiles, [position, :objects]) || []

  Enum.reduce(objects, {combat, []}, fn object, {acc, events} ->
    case Game.MapObject.on_enter(object, acc.current_turn.player, acc) do
      {:ok, updated} ->
        {updated, events}

      {:booster_pickup, updated} ->
        updated_grid = remove_object_at(updated.grid, position, object)
        {%{updated | grid: updated_grid}, [:booster_pickup | events]}

      _ ->
        {acc, events}
    end
  end)
end
```

Change the function signature to return `{combat_state, [events]}` and update its call site in
`process_action/2` to destructure accordingly. Broadcast the `:booster_pickup` event to the
LiveView via the existing state broadcast mechanism.

Add a private helper:

```elixir
defp remove_object_at(grid, position, object) do
  update_in(grid.tiles[position][:objects], fn objs ->
    List.delete(objs, object)
  end)
end
```

### 6. Map deserialization support

**File:** `lib/game/maps.ex` (or wherever `deserialize_objects/1` lives)

```elixir
defp deserialize_object(%{"type" => "booster"}), do: %Game.MapObject.Booster{}
```

### 7. Class selection flow in Game/LiveView

When the server broadcasts a `:booster_pickup` event, the LiveView must:
1. Show a class selection modal.
2. Player picks one class from: their current class + 2 random others.
3. Game generates a booster pack drawn from that class's pool.
4. Player picks cards from that pack (existing booster pick flow).

**In `lib/game.ex`:**

```elixir
def handle_booster_pickup(game_state, player_id) do
  player_class = get_player_class(game_state, player_id)
  all_classes = Game.Content.list_playable_classes() |> Enum.map(& &1.class)
  other_classes = all_classes |> Enum.reject(&(&1 == player_class)) |> Enum.take_random(2)
  class_options = [player_class | other_classes]

  put_in(game_state, [:pending_booster], %{player_id: player_id, class_options: class_options})
end
```

**In `lib/game_web/live/game_live.ex`:**

```elixir
def handle_event("select_booster_class", %{"class" => class}, socket) do
  game_id = socket.assigns.game_id
  player_id = socket.assigns.current_player.id
  Game.trigger_class_booster(game_id, player_id, class)
  {:noreply, socket}
end
```

**In `lib/game.ex`:**

```elixir
def trigger_class_booster(game_id, player_id, class) do
  cards = generate_booster_cards_for_class(class, booster_size)
  # Set player's booster_state and transition into the existing booster pick flow
end

defp generate_booster_cards_for_class(class, count) do
  import Ecto.Query

  pool =
    Game.Repo.one(
      from c in Game.Content.BaseClass,
      where: c.class == ^class,
      join: p in assoc(c, :booster_pool),
      join: bpc in assoc(p, :booster_pool_cards),
      join: card in assoc(bpc, :card),
      preload: [booster_pool: {p, booster_pool_cards: {bpc, card: card}}]
    )

  pool.booster_pool.booster_pool_cards
  |> Enum.flat_map(fn bpc -> List.duplicate(bpc.card, bpc.count) end)
  |> Enum.shuffle()
  |> Enum.take(count)
  |> Enum.map(&Game.Content.to_game_card/1)
end
```

The `count` field on `BoosterPoolCard` expands into repeated entries before shuffling, so higher
count means higher probability — matching how `BaseDeck.get_cards/1` works.

**Modal in the HUD/GameLive template:**

```heex
<.modal :if={@pending_booster && @pending_booster.player_id == @current_player.id}
        id="class-select-modal" show={true}>
  <h2>Choose a class for your booster pack</h2>
  <%= for class <- @pending_booster.class_options do %>
    <button phx-click="select_booster_class" phx-value-class={class}>{class}</button>
  <% end %>
</.modal>
```

---

## Critical Files

| File | Change |
|------|--------|
| `lib/game/content/booster_pool.ex` | New schema: `booster_pools` table |
| `lib/game/content/booster_pool_card.ex` | New join schema: `booster_pool_cards` table |
| `priv/repo/migrations/<ts>_create_booster_pools.exs` | New migration |
| `priv/repo/migrations/<ts>_create_booster_pool_cards.exs` | New migration |
| `priv/repo/migrations/<ts>_add_booster_pool_id_to_base_classes.exs` | FK on `base_classes` |
| `lib/game/content/base_class.ex` | Add `belongs_to :booster_pool` + cast |
| `lib/game_web/live/admin/base_class_live.ex` | Add booster pool selector |
| `lib/game_web/live/admin/booster_pool_live.ex` | New admin page for pool management |
| `lib/game/map_objects/booster.ex` | New map object returning `{:booster_pickup, ...}` |
| `lib/game/maps.ex` | Deserialize `"booster"` object type |
| `lib/game/combat.ex` | Handle `{:booster_pickup, ...}` in `apply_entry_effects` |
| `lib/game.ex` | Add `handle_booster_pickup/2`, `trigger_class_booster/3`, `generate_booster_cards_for_class/2` |
| `lib/game_web/live/game_live.ex` | Add `"select_booster_class"` event; render class select modal |

---

## Verification

1. Create a booster pool via admin; add cards to it with varying counts.
2. Assign the pool to a class via the class admin.
3. Place a `booster` object on a map tile (via map editor or seed data).
4. Start a combat on that map; move a character onto the booster tile.
5. Confirm the class selection modal appears with the player's class + 2 others.
6. Select a class — confirm a booster pack appears with cards drawn from that class's pool
   (higher-count cards should appear more frequently across multiple tests).
7. Pick a card — confirm it is added to the player's hand/deck.
8. Move another character to the same tile — confirm the booster is gone (consumed on first collect).
