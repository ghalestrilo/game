# Add Map Object Type

Add a new game object type that can appear on map tiles.

## Context

Map objects live on tiles in `objects: [...]`. They implement the `Game.MapObject` protocol (`lib/game/map_object.ex`), which has two callbacks:

- `blocks_movement?(object)` — returns bool; used by `Grid.tile_blocked?/2`
- `on_enter(object, character, combat_state)` — called after a character moves onto the tile; returns `{:ok, combat_state}` or a custom tagged tuple

Existing types: `Wall`, `Pickup`, `Breakable` in `lib/game/map_objects/`.

## Steps

1. **Create** `lib/game/map_objects/<name>.ex`:

```elixir
defmodule Game.MapObject.<Name> do
  @derive Jason.Encoder          # required — combat state is JSON-serialized during card targeting
  defstruct field: default, ...

  defimpl Game.MapObject do
    def blocks_movement?(_obj), do: false   # or true
    def on_enter(_obj, _character, combat_state), do: {:ok, combat_state}
  end
end
```

2. **Add deserialization** in `Game.Maps.deserialize_objects/1` (`lib/game/maps.ex`) so DB maps can include this type:

```elixir
%{"type" => "<name>", ...fields} -> %Game.MapObject.<Name>{...}
```

3. **Add rendering** in `lib/game_web/live/combat_live.ex` if the object needs visual representation (see `wall?/1` pattern).

## Critical constraint

`@derive Jason.Encoder` is mandatory. Without it, selecting a card on a map that contains this object type will crash with `Protocol.UndefinedError` — `build_tile_overlay/2` in `card.ex` serializes the entire combat state including grid tiles.

## Test

Add a case to `test/game/combat_test.exs` under `"build_tile_overlay with map objects on grid"` that puts the new object in a tile and calls `Card.build_tile_overlay/2` — this catches the JSON serialization crash.
