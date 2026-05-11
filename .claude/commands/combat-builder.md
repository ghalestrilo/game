# CombatBuilder Reference

Context for working with `Game.CombatBuilder` (`lib/game/combat_builder.ex`).

## What it does

Builds a fully initialized `CombatState` from a list of player specs and options. Called at three sites:
- `LobbyServer.maybe_start_game/1` — PvP game start
- `LobbyServer.start_single_player_game/2` — campaign / sandbox
- `Game.handle_call({:pick_booster_card, ...})` — combat rebuild after all boosters picked

## Call signature

```elixir
Game.CombatBuilder.build(player_specs, opts \\ [])
```

### `player_specs` — list of maps, each with:
- `:class` — string looked up from DB via `Content.get_base_class_by_class!/1`
- `:team` — integer or string team identifier
- `:id` — integer character id
- `:position` — `{q, r, s}` tuple **or omitted** (auto-assigned — see below)
- `:character` — optional pre-built `Character.t()` (skips DB lookup)
- `:name` — optional display name override

### `opts` — keyword list:
- `:map` — atom or string slug; loaded via `Game.Maps.get/1` (DB-first, falls back to builtin)
- `:settings` — lobby settings map; `:map` key used if `:map` opt absent

Both `:map` and `:settings` are handled by `resolve_map/1` — it checks `opts[:map]` first, then `get_in(opts[:settings], [:map])`. Existing callers using `[map: slug]` are unaffected.

## Auto-position assignment

If **any** spec is missing `:position`, all specs go through `assign_positions/2`:
1. Map spawn points filled in order (`MapTemplate.spawn_points` values)
2. Overflow specs get a `:random` sentinel
3. `:random` sentinels resolved to shuffled free non-wall tiles from a scratch grid

This means callers can pass `%{class: "fighter", team: 1, id: 0}` with no position and the builder places them automatically.

## Map overlay

When a `MapTemplate` is resolved, `build_grid/2` creates a full hex grid then merges the template's sparse tile map over it. Template tiles carry `%{terrain: atom, objects: [...]}` — `occupied_by` is always set by the character placement step afterward.

## Adding a new option

1. Add a clause to `resolve_map/1` or add a new `defp resolve_*/1` helper
2. Thread it through `build/2` before the character-build step
3. Pass it from all three call sites (LobbyServer ×2, game.ex ×1)
4. Add a `CombatBuilderTest` case in `test/game/combat_builder_test.exs` — use `Game.DataCase, async: false` and call `seed_base_classes()` in setup

## Key invariants

- `combat.queue` excludes the current player — use `CombatState.get_current_queue(combat)` to get all
- Characters placed by the builder have full cards drawn, HP/AP set to max, `dead: false`
- The grid in the returned `CombatState` already has characters set in `occupied_by` for their tiles
- `CombatBuilder` is stateless and pure (modulo DB lookups) — safe to call from any process

## Current call sites

```elixir
# lobby_server.ex — PvP start
Game.CombatBuilder.build(specs, settings: state.settings)

# lobby_server.ex — single-player
Game.CombatBuilder.build(build_opts.combatants, map_opt)

# game.ex — post-booster rebuild
Game.CombatBuilder.build(specs, settings: state[:settings])
```
