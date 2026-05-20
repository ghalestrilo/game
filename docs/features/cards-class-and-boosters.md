# Feature: Card Classes and Map Boosters

## Context

Cards need a `:class` field so they can be associated with a specific character class and appear
selectively in booster packs. When a player walks over a booster pickup on the map, it triggers a
class selection modal (player's own class + 2 random others), and the resulting booster pack is
filtered to that chosen class's cards.

Boosters already exist as a pre-combat draft mechanic (lobby phase). This feature adds an in-game
booster pickup triggered by map exploration.

---

## Implementation Plan

### 1. Add `:class` field to BaseCard

**File:** `lib/game/base_cards/base_card.ex`

Add a nullable string field `:class`. A card with `class: nil` is class-agnostic and can appear in
any booster; a card with a class value only appears in that class's booster pool.

```elixir
field :class, :string
```

Add `:class` to the `cast` list in `changeset/2`. No `validate_required` — it is optional.

**Migration:**

```elixir
alter table(:cards) do
  add :class, :string
end
```

**Admin UI** (`lib/game_web/live/admin/base_card_live.ex`): add a `class` text field (or a
BelongsTo-style select if you prefer referencing BaseClass names). A simple text field is the
minimal approach since `:class` is a string matching BaseClass's `:class` field.

### 2. Create the Booster map object

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

### 3. Handle `{:booster_pickup}` in combat entry effects

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
        # Remove the booster from the tile so it can't be collected twice
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
LiveView via the existing state broadcast mechanism (same path as animations).

Add a private helper to remove one object from a tile:
```elixir
defp remove_object_at(grid, position, object) do
  update_in(grid.tiles[position][:objects], fn objs ->
    List.delete(objs, object)
  end)
end
```

### 4. Map deserialization support

**File:** `lib/game/maps.ex` (or wherever `deserialize_objects/1` lives)

Add `"booster"` to the object type switch:

```elixir
defp deserialize_object(%{"type" => "booster"}), do: %Game.MapObject.Booster{}
```

### 5. Class selection flow in Game/LiveView

When the server broadcasts a `:booster_pickup` event, the LiveView must:
1. Show a class selection modal.
2. Player picks one class from: their current class + 2 random others.
3. Game generates a booster pack filtered to that class's cards.
4. Player picks cards from that pack (using the existing booster picking flow).

**In `lib/game.ex`** (or the module that drives game state updates):

Add a handler for the booster pickup event that attaches `pending_booster: {player_id, [class_options]}` to the game state so the LiveView can render the modal.

```elixir
def handle_booster_pickup(game_state, player_id) do
  player_class = get_player_class(game_state, player_id)
  all_classes = Game.Content.list_playable_classes() |> Enum.map(& &1.class)
  other_classes = all_classes |> Enum.reject(&(&1 == player_class)) |> Enum.take_random(2)
  class_options = [player_class | other_classes]

  put_in(game_state, [:pending_booster], %{player_id: player_id, class_options: class_options})
end
```

**In `lib/game_web/live/game_live.ex`** (or `combat_live.ex`):

Add a `"select_booster_class"` event handler:

```elixir
def handle_event("select_booster_class", %{"class" => class}, socket) do
  game_id = socket.assigns.game_id
  player_id = socket.assigns.current_player.id

  Game.trigger_class_booster(game_id, player_id, class)
  {:noreply, socket}
end
```

**In `lib/game.ex`**:

```elixir
def trigger_class_booster(game_id, player_id, class) do
  cards = generate_booster_cards_for_class(class, booster_size)
  # Set player's booster_state and transition them into the existing booster pick flow
end
```

Add a `generate_booster_cards_for_class/2` function that:
- Queries `BaseCard` where `class == chosen_class OR class IS NULL` (class-agnostic cards are always
  eligible)
- Randomly samples `booster_size` cards from that pool

```elixir
defp generate_booster_cards_for_class(class, count) do
  import Ecto.Query
  Game.Repo.all(
    from c in Game.BaseCards.BaseCard,
    where: c.class == ^class or is_nil(c.class)
  )
  |> Enum.shuffle()
  |> Enum.take(count)
  |> Enum.map(&Game.Content.to_game_card/1)
end
```

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
| `lib/game/base_cards/base_card.ex` | Add `:class` string field + cast |
| `priv/repo/migrations/<ts>_add_class_to_cards.exs` | New migration: `add :class, :string` |
| `lib/game_web/live/admin/base_card_live.ex` | Add `class` field to admin UI |
| `lib/game/map_objects/booster.ex` | New map object returning `{:booster_pickup, ...}` |
| `lib/game/maps.ex` | Deserialize `"booster"` object type |
| `lib/game/combat.ex` | Handle `{:booster_pickup, ...}` in `apply_entry_effects` |
| `lib/game.ex` | Add `handle_booster_pickup/2`, `trigger_class_booster/3`, `generate_booster_cards_for_class/2` |
| `lib/game_web/live/game_live.ex` | Add `"select_booster_class"` event; render class select modal |

---

## Verification

1. Add `:class` to a few cards via admin (e.g. set class to "warrior" on 3 cards).
2. Place a `booster` object on a map tile (via map editor or seed data).
3. Start a combat on that map; move a character onto the booster tile.
4. Confirm the class selection modal appears with the player's class + 2 others.
5. Select a class — confirm a booster pack appears with cards filtered to that class (plus
   class-agnostic cards).
6. Pick a card — confirm it is added to the player's hand/deck.
7. Move another character to the same tile — confirm the booster is gone (consumed on first collect).
