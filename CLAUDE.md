# CLAUDE.md

Developer reference for this Elixir/Phoenix LiveView roguelike deckbuilder. Read before touching combat, cards, AI, or the 3D board. For commands and code style, see `CRUSH.md`.

---

## Architecture at a glance

Turn-based tactical deckbuilder on a hex grid. Single OTP app (not umbrella). PostgreSQL + Oban + PubSub.

**Three game modes** (set as `live_action` in `GameLive`): `:sandbox`, `:campaign`, `:pvp`

**Primary action flow:**
```
UI event / keydown
  → GameWeb.CombatController.dispatch/2     # validates turn ownership
  → to_action/2                             # intent map → action tuple
  → Game.process_action/3                   # GenServer.call
  → Game.Combat.process_action/2            # pure rule validation
  → Game.AI.advance_through_ai_turns/1      # auto-runs AI turns
  → Phoenix.PubSub broadcast {:game_updated, state, animations}
  → GameLive.handle_info/3                  # assigns updated, LiveView re-renders
```

---

## Key modules

| Module | Role |
|--------|------|
| `Game` (`lib/game.ex`) | GenServer game loop; owns state; broadcasts on every change |
| `Game.Combat` | Pure action validation + processing; returns `{:ok, state}` or `{:ok, state, animations}` |
| `Game.CombatState` | Pure state mutation helpers (`get_current_player/1`, `tick_status_effects/1`, etc.) |
| `Game.Card` | Card struct + effect dispatch; `@effect_types` registry; `build_effect_context/3` |
| `Game.Character` | Combatant struct; `from_character_data/1` builds from `BaseClass` |
| `Game.Grid` | Hex cube coords; `distance/3`, `tiles_in_range/3`, `direction_toward/3`, `move_toward/4`, `tile_blocked?/2` |
| `Game.Formula` | JsonLogic evaluator; `resolve/2` expands `{"alias": [...]}` nodes from DB |
| `Game.FormulaAliases` | Named reusable JsonLogic expressions |
| `Game.AI` | `run_turn/2`, `advance_through_ai_turns/1`; circuit breaker at 10 actions/turn |
| `Game.CombatBuilder` | `build/2` assembles `CombatState` from specs; handles position assignment |
| `Game.Maps` / `Game.Maps.MapTemplate` | DB map → runtime grid pipeline |
| `Game.Content` | Context for DB content (BaseCard, BaseDeck, BaseClass, Strategy, FormulaAlias) |
| `GameWeb.GameLive` | Main LiveView; subscribes to `Game.PubSub`; mounts per mode |
| `GameWeb.CombatController` | Intent dispatch; `key_to_intent/2`, `event_to_intent/3`, `dispatch/2` |
| `GameWeb.GameBoard3D` | Three.js LiveComponent; `default_assets/0`; pushes `init` and `board_state` to hook |

---

## Hex grid

Cube coordinates `{q, r, s}` where `q + r + s = 0` always.  
Distance = `max(|Δq|, |Δr|, |Δs|)`.  
Directions are integers 0–5 (clockwise from east).

---

## Card effect system

Effects are structs implementing the `Game.Combat.CardEffect` protocol.

**Protocol callbacks:** `process/3`, `get_description/1`, `get_icon/1`, `get_value_label/1`, `animate/1`, `params/1`

**Rules for every new effect:**

- `@derive Jason.Encoder` is required — without it, state silently fails to serialize for LiveView
- Do NOT add `@impl Game.Combat.CardEffect` — it causes compiler warnings (protocol impl is detected automatically)
- Register in `Game.Card.@effect_types`: `"type_name" => CardEffects.ModuleName`
- `process/3` receives an already-resolved `value` — JsonLogic formulas are evaluated before `process/3` is called
- New status effects that tick need a matching clause in `CombatState.tick_status_effects/1`
- Dead characters are skipped by default. Effects that target dead characters (like revive) need an exemption in the `dead_skip` guard in `Card.apply_card_effects/3`

Existing effect modules in `lib/game/combat/card_effects/`: `damage`, `heal`, `shield`, `move`, `draw`, `discard`, `dot`, `regen`, `stun`, `slow`, `stuck`, `stealth`, `ethereal`, `hex`, `cleanse`, `give`, `modify_attribute`, `self_destruct`, `summon`, `revive`

---

## Data pipeline: DB → runtime

```
Game.Maps.Map (DB)
  tiles: [%{"q"=>int, "terrain"=>"plain", "objects"=>[]}]   # JSON strings
  spawn_points: %{"team_1" => [q, r, s]}                    # string keys, list coords
        ↓  Game.Maps.from_db/1
Game.Maps.MapTemplate
  tiles: %{{q,r,s} => %{terrain: :plain}}                   # atom keys, tuple coords
  spawn_points: %{team_1: {q,r,s}}                          # atom keys, tuple coords
        ↓  CombatBuilder.build_grid/2
Game.Grid (combat runtime)
  tiles: %{{q,r,s} => %{terrain: :plain, occupied_by: nil}}
```

Spawn point keys: DB stores `"team_N"` strings; runtime uses `:team_N` atoms.  
Use `String.to_atom/1` (NOT `to_existing_atom`) when deserializing team keys — new team numbers may not be interned.

---

## Formula system (JsonLogic)

`Game.Formula.resolve/2` evaluates JsonLogic maps. `{"alias" => ["name"]}` nodes are expanded from the DB before evaluation.

**Card effect context variables** (built in `Card.build_effect_context/3`):

| Variable | Type | Notes |
|----------|------|-------|
| `caster.*` | map | `hp`, `max_hp`, `ap`, `max_ap`, `position` (list), `team`, `status_effects`, `cards.*` |
| `target.*` | map | Character map or `%{"position" => [q,r,s]}` for tile targets |
| `state` | map | Full encoded `CombatState` |
| `distance_from_caster` | int | Distance at resolution time |
| `cast_distance` | int | Distance at card selection time (frozen); nil for self-targeting cards |
| `push_delta` | map `{q,r,s}` | Direction from caster toward target |
| `pull_delta` | map `{q,r,s}` | Direction from target toward caster |
| `angle_toward_target` | int 0–5 | |
| `angle_toward_caster` | int 0–5 | |
| `angle_push_from_blast` | int 0–5 | AoE only; nil for single-target |
| `angle_pull_from_blast` | int 0–5 | AoE only |
| `push_delta_from_blast` | map | AoE only |
| `pull_delta_from_blast` | map | AoE only |
| `cards_played_this_turn` | int | Resets each turn |

**AI tactic context** only has `caster`, `queue`, `state` — no directional variables.

**Atom/string gotcha:** Status effect types are atoms in Elixir (`:stealth`) but strings in formula context. Always compare with string literals: `{"==": [{"var": "type"}, "stealth"]}`.

---

## AI strategies

Strategy = ordered list of tactics. Each turn, AI scans from the top, evaluates `trigger`, and executes the first match. After each action it restarts the scan from the top.

- **Always end with a `skip_turn` fallback.** Without it the circuit breaker (`@max_actions = 10`) fires and logs a warning every turn.
- Action `"type"` values: `"move_closer"`, `"move_away"`, `"skip_turn"`, or any card effect name (with optional `"card_filter"`).
- `"target_id"` must resolve to the character's integer `id`, not the full character map.
- `queue` in AI context includes dead characters — filter with `{"!==": [{"var": "current.dead"}, true]}` if needed.

---

## 3D board (Three.js)

Assets served from Tigris object storage via `ASSETS_BASE_URL` env var (dev default in `config/dev.exs`).

**Critical gotchas:**

- Characters **must** use `cloneSkeleton()` from `SkeletonUtils.js`, NOT `.clone()`. Plain `.clone()` produces invisible skinned meshes (bones point to the template skeleton, not the scene).
- Animation crossfade: use `.crossFadeFrom()` on the **destination** clip, NOT `.crossFadeTo()` on the source. Source-based crossfade leaves the source disabled and unrecoverable via `.play()` alone.
- All GLB assets are Y-up; scene is Z-up. Rotations:
  - Tiles/objects: `rotation.set(Math.PI/2, Math.PI/6, 0)`
  - Characters: `rotation.set(Math.PI/2, 0, 0)`, yaw via `rotation.y`
- `camera.up.set(0, 0, 1)` must be called **before** constructing `OrbitControls`.

Adding a new asset key to `default_assets/0` in `GameBoard3D` is sufficient for loading. No hook code changes needed unless the asset needs new rendering logic in `_syncTiles` or `_syncCharacters`.

---

## Testing

- `Game.Fixtures` — pure in-memory test data, no DB. Use with `async: true`.
- DB-dependent tests: `use Game.DataCase, async: false` and call `Game.DataCase.seed_base_classes()` in setup.

Key test files:
- `test/game/combat_test.exs` — core combat actions
- `test/game/combat_builder_test.exs` — position assignment
- `test/game_web/live/sandbox_live_test.exs` — sandbox URL params + rendering

---

## Known code smells (don't replicate)

1. `Game.Card` violates SRP — owns effect processing, targeting, JSON encoding, and animations.
2. `build_data_context`, `build_effect_context`, and `build_tile_overlay` each JSON-encode combat state independently (triplicate).
3. `temporary_hack` filter in `Card` duplicates `get_structured_effect` logic.
4. `Combat.process_action/2` returns `{:ok, state}` for moves and `{:ok, state, animations}` for card plays — callers must handle both shapes.
5. `Card.@effect_types` and `Combat` maintain separate effect type lists — keep them in sync when adding new effects.

---

## Skills (step-by-step guides)

Invoke with `/skill-name` or via `Skill` tool. Files in `.claude/skills/`:

| Skill | When to use |
|-------|-------------|
| `card-effect` | Adding a new card effect type (module, registration, status tick) |
| `add-ai-strategy` | Authoring a new Strategy + JsonLogic tactics |
| `grid-map` | Hex grid operations, AoE, movement cards |
| `formula-debug` | Tracing or fixing a JsonLogic formula |
| `formula-alias` | Creating reusable named formula expressions |
| `add-3d-model` | Adding tile variants, map objects, or animated characters |
| `status-effect-ui` | Adding icons, badges, board overlays for status effects |
| `admin-content` | Creating cards/decks/classes via Ecto or admin UI |
| `add-combat-intent` | Wiring a new action through keyboard, UI events, and AI |
| `map-editor` | DB map schema, tile editor, spawn points, content sync |
| `combat-sim` | Simulating combat in IEx for balance testing |

**Slash commands** in `.claude/commands/`: `/sandbox`, `/tdd-combat`, `/combat-builder`, `/add-map-object`, `/add-map`
