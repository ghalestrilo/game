Code Quality Analysis: combat.ex, card.ex, combat_live.ex                                                                                                                                                                              

 Context

 The game is working well. This is a code quality review — identifying mixed responsibilities and proposing clean breakdowns. No behavior changes intended.

 ---
 Game.Combat (lib/game/combat.ex, 374 lines)

 Current responsibilities

 1. Combat initialization — initialize_from_char_params_list/1 (62-line function that does character creation, grid sizing, position validation, and CombatState assembly)
 2. Action dispatch — process_action/2 handles move, pick_card, play_card, play_card_on_character, skip_turn
 3. Validation logic — AP check, range check, ethereal/stealth check, movement range check (partly duplicated between the two play_card clauses)
 4. Movement range calculation — effective_movement_range/1 (private) applies stuck/slow effects to base attribute
 5. Reference metadata — get_available_card_effects/0 returns a hardcoded list that duplicates Game.Card.@effect_types

 Issues

 - Ethereal/stealth check is duplicated between play_card and play_card_on_character clauses (lines 151-154 and 201-210)
 - get_available_card_effects/0 has a different list than Game.Card.@effect_types (card.ex has modify_attribute, combat.ex does not); only one source of truth needed
 - effective_movement_range/1 would be reusable by AI/pathfinding if it lived in Game.Character

 Proposed changes

 1. Move effective_movement_range/1 to Game.Character as a public function — it operates only on a character struct and its status effects; Combat can call Character.effective_movement_range(player)
 2. Replace get_available_card_effects/0 with Game.Card.effect_types() |> Map.keys() — single source of truth; delete the hardcoded list in combat.ex
 3. Extract a private validate_card_target/3 that unifies the stealth/ethereal check used by both play_card clauses
 4. initialize_from_char_params_list/1 is complex but appropriately placed; no extraction needed unless a CombatBuilder module is introduced later

 ---
 Game.Card (lib/game/card.ex, 625 lines)

 Current responsibilities

 1. Data structure — defstruct, @type t(), JSON encoder (lines 32-114)
 2. Effect execution — process_card/3, apply_card_effects/3, apply_aoe_effect/5 (lines 116-208)
 3. Formula context building — build_effect_context, blast context, caster/target serialization (lines 210-303)
 4. Geometric calculations — compute_pull_delta, compute_push_delta, compute_angle_toward, compute_distance_from_caster, compute_cast_distance (lines 305-338)
 5. Effect data parsing — get_structured_effect/1 (4 clauses), build_effect_struct, unpack_params_map, effect_params (lines 340-427)
 6. Card state queries — selectable?, effect_implemented?, get_targeting_type, is_one_time_use? (lines 428-445, 614-622)
 7. Targeting validation — is_target_cell_valid?, is_target_valid_for_character?, build_data_context, build_target_data (lines 447-512, 516-529, 585-611)
 8. UI overlay generation — build_tile_overlay, aoe_radius (lines 531-582)

 Issues

 - Formula context building (build_effect_context) serializes the entire combat state to JSON and back on every effect resolution — expensive in AoE situations
 - Targeting validation (is_target_cell_valid?, is_target_valid_for_character?, build_data_context) builds a completely separate context (smaller, different variable names) from the effect formula context — these two contexts should
 be consistent
 - @formula_operators MapSet hardcoded in card.ex couples it to JsonLogic internals
 - JSON encoding for effects and conditional_effects is duplicated (lines 75-88 and 91-104)

 Proposed changes (conservative — no file splits needed)

 1. Extract encode_effects_for_json/1 private helper to deduplicate the tuple-to-list conversion (saves ~15 lines, DRYs the Jason.Encoder impl)
 2. No file splits — the module groupings are coherent enough that splitting would scatter related logic without clear gain. The module is long but well-organized into logical sections that work together.

 Note on targeting context vs formula context

 The two contexts (build_data_context for JsonLogic targeting rules, build_effect_context for formula resolution) serve different purposes and intentionally expose different variables. This is fine as-is.

 ---
 GameWeb.CombatLive (lib/game_web/live/combat_live.ex, 314 lines)

 Current responsibilities

 1. LiveComponent lifecycle — update/2 builds overlay and tile JSON on every state update
 2. Rendering — render/1 outputs the board, entity layer, and game-over modal
 3. Event pass-through — 3 handle_event clauses that immediately forward to parent via send
 4. Tile CSS building — build_tile_classes_json/3, encode_coord/1, encode_blast_map/1
 5. Board geometry — build_position_index/1 computes pixel coordinates for hex tiles
 6. Character rendering — character_style/2, character_bg/1, character_filter_class/2, stealthy?/1
 7. Game-rule queries — visible_to?/2, within_movement_range?/2, current_turn_visible?/3, current_player_at?/3

 Issues

 - visible_to?/2 and within_movement_range?/2 implement game rules (fog-of-war, movement mechanics) inside a rendering component; they should be in the Game context
 - Hard-coded layout constants (cell = 80, gap = 8, vertical scaling 0.92) scattered across functions
 - The 3 handle_event pass-throughs are noise; they could be removed entirely in favor of routing events directly to the parent (depending on Phoenix LiveComponent architecture)

 Proposed changes

 1. Move visible_to?/2 to Game.Character as a public function — it's a game rule about team visibility, not presentation. CombatLive calls Character.visible_to?(character, current_player).
 2. Move within_movement_range?/2 to Game.CombatState — it queries combat state to determine movement range; that logic belongs there.
 3. Extract layout constants to module attributes in CombatLive — @cell_size 80, @cell_gap 8, @vertical_scale 0.92 so they appear once.

 ---
 Summary of changes

 ┌───────────────────────────────────────────────────────────────┬─────────────────────────────────┬───────┐
 │                            Change                             │              File               │ Size  │
 ├───────────────────────────────────────────────────────────────┼─────────────────────────────────┼───────┤
 │ Move effective_movement_range/1 → Game.Character              │ combat.ex, character.ex         │ Small │
 ├───────────────────────────────────────────────────────────────┼─────────────────────────────────┼───────┤
 │ Replace get_available_card_effects/0 with Card.effect_types/0 │ combat.ex, call sites           │ Tiny  │
 ├───────────────────────────────────────────────────────────────┼─────────────────────────────────┼───────┤
 │ Extract private validate_card_target/3                        │ combat.ex                       │ Small │
 ├───────────────────────────────────────────────────────────────┼─────────────────────────────────┼───────┤
 │ Extract encode_effects_for_json/1 helper                      │ card.ex                         │ Tiny  │
 ├───────────────────────────────────────────────────────────────┼─────────────────────────────────┼───────┤
 │ Move visible_to?/2 → Game.Character                           │ combat_live.ex, character.ex    │ Small │
 ├───────────────────────────────────────────────────────────────┼─────────────────────────────────┼───────┤
 │ Move within_movement_range?/2 → Game.CombatState              │ combat_live.ex, combat_state.ex │ Small │
 ├───────────────────────────────────────────────────────────────┼─────────────────────────────────┼───────┤
 │ Extract layout constants to module attributes                 │ combat_live.ex                  │ Tiny  │
 └───────────────────────────────────────────────────────────────┴─────────────────────────────────┴───────┘

 Verification

 - Run mix test — no behavior change, all tests should pass
 - Manual smoke test: play a card, move a character, check tile overlay highlights, check stealth visibility
 - Check get_available_card_effects call sites to confirm replacement doesn't break anything