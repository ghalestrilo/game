# Add Map

Scaffold a new named map for the game.

## Usage
/add-map <slug> [display_name]

## What this does

Creates a new map entry in `Game.Maps` (`lib/game/maps.ex`) under `@builtin_maps`.

A map has:
- `slug` — atom key, e.g. `"forest_clearing"`
- `display_name` — human-readable string
- `tiles` — sparse `%{{q,r,s} => %{terrain: :plain, objects: [...]}}` — only non-default tiles needed
- `spawn_points` — `%{team_1: {q,r,s}, team_2: {q,r,s}}` — one per starting team

## Object types available

- `%Game.MapObject.Wall{}` — blocks movement and card targeting
- `%Game.MapObject.Breakable{hp: n, max_hp: n, blocks_movement: true}` — destructible blocker
- `%Game.MapObject.Pickup{item: :atom, quantity: n}` — collected on entry

## Coordinate system

Hex cube coords `{q, r, s}` where `q + r + s = 0`. Origin `{0,0,0}` is center. Spawn points should be at least radius 3 from center to give movement room.

## Steps

1. Add the map struct to `@builtin_maps` in `lib/game/maps.ex`
2. Add a DB seed entry at the bottom of `priv/repo/seeds.exs` using `Game.Maps.create_map/1` — tiles as list of maps with string keys `"q"/"r"/"s"/"terrain"/"objects"`, spawn_points as `%{"team_1" => [q,r,s], "team_2" => [q,r,s]}`
3. Test it: `/sandbox?characters=fighter,mage&map=<slug>`

## Verification

```
mix run -e "IO.inspect Game.Maps.get(\"<slug>\")"
```
