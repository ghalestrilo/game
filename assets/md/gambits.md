                                                                                                           
# Context                                                                                                  

 No AI exists — all turns are player-driven via LiveView events. The queue treats every character
 identically. When it's an enemy's turn the game just waits. We need a FF12-style gambit system: a
 prioritised list of {trigger, action} pairs stored on the creature's class in the DB, evaluated
 top-to-bottom each turn until one fires or AP/cards run out.

 JSONLogic already drives targeting rules and procedural effect values, so it's the natural fit for
 triggers too. The data context available (caster, queue, state) is sufficient to express virtually any
 gambit condition.

 ---
 DB layer — base_classes.gambits column

 Add a gambits column to base_classes (type :array of :map, i.e. jsonb[]). No new table needed — gambits
 belong to a class, not a card.

 Migration:
 ALTER TABLE base_classes ADD COLUMN gambits jsonb[] DEFAULT '{}';

 Schema change (lib/game/content/base_class.ex):
 field :gambits, {:array, :map}, default: []

 Gambit shape (one element of the array):
 {
   "trigger": { "JsonLogic expression" },
   "action":  "heal" | "damage" | "skip_turn" | "move_closer" | "move_away",
   "card_filter": "heal" | "damage" | null
 }

 - trigger — JsonLogic evaluated against a context of %{"caster" => ..., "queue" => [...], "state" => ...}.
  Returns truthy to fire.
 - action — what to do when trigger fires. "skip_turn" is the terminal action.
 - card_filter — when action is a card play, which effect type to prefer. The AI picks the first card in
 hand that contains a matching effect type.

 Example wolf gambits:
 [
   { "trigger": {"some": [{"var":"queue"}, {"<": [{"var":"current.hp"}, {"*": [{"var":"current.max_hp"},
 0.15]}]}]},
     "action": "skip_turn" },
   { "trigger": true, "action": "damage", "card_filter": "damage" },
   { "trigger": true, "action": "skip_turn" }
 ]

 ---
 Runtime layer — Game.AI module

 New file: lib/game/ai.ex

 Responsible for running one full AI turn given a CombatState. Returns {:ok, updated_combat}.

 defmodule Game.AI do
   @max_actions 10  # circuit-breaker

   def run_turn(combat_state, gambits) do
     do_run(combat_state, gambits, @max_actions)
   end

   defp do_run(combat, _gambits, 0), do: {:ok, combat}  # circuit-breaker
   defp do_run(combat, gambits, remaining) do
     caster = CombatState.get_current_player(combat)
     context = build_context(caster, combat)

     case find_matching_gambit(gambits, context) do
       nil ->
         {:ok, skip(combat, caster)}

       %{"action" => "skip_turn"} ->
         {:ok, skip(combat, caster)}

       gambit ->
         case execute(gambit, caster, combat) do
           {:ok, updated_combat} -> do_run(updated_combat, gambits, remaining - 1)
           {:error, _}           -> {:ok, skip(combat, caster)}
         end
     end
   end
 end

 find_matching_gambit/2 — iterates the list, calls Game.Formula.resolve(trigger, context), returns first
 truthy.

 execute/3 — dispatches on action:
 - "damage" / "heal" / "shield" etc — picks best card via card_filter, finds a valid target via
 Card.is_target_cell_valid?, calls Combat.process_action(combat, {:play_card, position})
 - "move_closer" — finds nearest enemy tile within movement_range, calls Combat.process_action(combat,
 {:move, caster, pos})
 - "move_away" — finds tile that maximises distance from nearest enemy
 - "skip_turn" — calls skip/2

 build_context/2 — same Jason encode/decode pattern as targeting and effect resolution:
 %{
   "caster" => <serialized caster>,
   "queue"  => <serialized full queue including current player>,
   "state"  => <serialized combat_state>
 }

 "queue" as a list lets gambits use JsonLogic array operators (some, all, filter) to inspect allies and
 enemies — e.g. {"some": [{"var":"queue"}, ...]}.

 ---
 Character / BaseClass integration

 Character struct — add gambits field (default []):
 # lib/game/character.ex
 field :gambits, default: []

 Character.from_character_data/1 — map base_class.gambits onto the character struct.

 is_ai_controlled?/1 — def is_ai_controlled?(%{gambits: [_ | _]}), do: true; def is_ai_controlled?(_), do:
 false

 Characters with a non-empty gambits list are AI-controlled. No separate boolean flag needed — the gambits
 list itself is the signal.

 ---
 Turn-advance hook — CampaignPlayLive

 After every action that advances the turn (skip_turn, successful play_card), check if the new
 current_turn.player is AI-controlled and auto-run their turn:

 # lib/game_web/live/campaign/campaign_play_live.ex
 defp maybe_run_ai_turn(%{combat: %{current_turn: %{player: player}} = combat} = game_state) do
   if Character.is_ai_controlled?(player) do
     {:ok, updated_combat} = Game.AI.run_turn(combat, player.gambits)
     %{game_state | combat: updated_combat}
   else
     game_state
   end
 end

 Call this after updating game_state in handle_event("skip_turn", ...) and handle_event("interact", ...)
 (after a successful card play). It recurses naturally: if after the AI turn it's another AI's turn,
 maybe_run_ai_turn fires again until a human turn is reached.

 ---
 Files to create / modify

 ┌───────────────────────────────────────────────────────────┬──────────────────────────────────────────┐
 │                           File                            │                  Change                  │
 ├───────────────────────────────────────────────────────────┼──────────────────────────────────────────┤
 │ priv/repo/migrations/<ts>_add_gambits_to_base_classes.exs │ New migration: add gambits jsonb[]       │
 ├───────────────────────────────────────────────────────────┼──────────────────────────────────────────┤
 │ lib/game/content/base_class.ex                            │ Add gambits field                        │
 ├───────────────────────────────────────────────────────────┼──────────────────────────────────────────┤
 │                                                           │ Add gambits field; update                │
 │ lib/game/character.ex                                     │ from_character_data/1; add               │
 │                                                           │ is_ai_controlled?/1                      │
 ├───────────────────────────────────────────────────────────┼──────────────────────────────────────────┤
 │ lib/game/ai.ex                                            │ New — full AI turn runner                │
 ├───────────────────────────────────────────────────────────┼──────────────────────────────────────────┤
 │ lib/game_web/live/campaign/campaign_play_live.ex          │ Add maybe_run_ai_turn/1, call after      │
 │                                                           │ turn-advancing events                    │
 └───────────────────────────────────────────────────────────┴──────────────────────────────────────────┘

 ---
 Verification

 mix test test/game/ai_test.exs        # unit tests for gambit evaluation
 mix test                              # full suite, no regressions

 Manual: start the campaign as a human, skip turn — the wolf should automatically act based on its gambits,
  then control returns to the player.

 ---
 Plan: Procedural Card Effect Values via JSONLogic

 Context

 Card effects currently only support static values (integers or strings). We need to support procedural
 values — JSONLogic expressions that are evaluated at resolution time using the current game state.
 Example: a damage card that deals damage equal to the caster's current HP, or the difference between max
 and current HP.

 The project already uses JSONLogic for targeting rules (Card.is_target_cell_valid?/3), so the
 infrastructure is in place.

 Approach

 Resolve procedural values in apply_card_effects/3 in lib/game/card.ex, immediately before
 CardEffect.process/3 is called. This is the only location that has both the effect struct and the
 combat_state in scope. Effect modules (damage.ex, heal.ex, etc.) remain unchanged — they always receive a
 plain resolved value.

 Key rule: if effect.value is a map(), resolve it with Game.Formula.resolve/2; otherwise pass through
 as-is.

 Context keys available to expressions

 %{
   "caster" => <serialized current_turn.player>,
   "target" => <serialized target character or position>,
   "state"  => <serialized combat_state>
 }

 Serialization uses the same Jason.encode/decode round-trip already used in build_data_context/2.

 Files to modify

 - lib/game/card.ex — core change (add resolve_effect_value/3 and build_effect_context/2)
 - test/game/combat/card_effects/damage_test.exs — TDD: add procedural value describe block
 - test/game/card_test.exs — TDD: add integration test with procedural value through process_card/3
 - Type annotation only (broaden value: integer() to value: integer() | map()): damage.ex, heal.ex,
 shield.ex, draw.ex, discard.ex

 Implementation (TDD order)

 Step 1 — Write failing tests

 test/game/combat/card_effects/damage_test.exs — new describe block:

 describe "Damage effect with procedural value" do
   # setup with warrior hp: 15, max_hp: 20 and mage as target

   test "value from caster.hp expression"
   # %Damage{value: %{"var" => "caster.hp"}} → deals 15 damage

   test "arithmetic expression: caster.max_hp - caster.hp"
   # %Damage{value: %{"-" => [%{"var" => "caster.max_hp"}, %{"var" => "caster.hp"}]}} → deals 5

   test "value from target.hp expression"
   # %Damage{value: %{"var" => "target.hp"}} → deals target.hp damage
 end

 test/game/card_test.exs — end-to-end:
 test "process_card/3 resolves procedural damage value from caster hp"
 # card with %{"type" => "damage", "value" => %{"var" => "caster.hp"}}
 # run through Card.process_card/3; assert damage == caster.hp

 Step 2 — Implement in lib/game/card.ex

 1. Update apply_card_effects/3 reduce body:
 effect
 |> get_structured_effect()
 |> resolve_effect_value(target, combat_state)
 |> CardEffect.process(target, combat_state)
 2. Add resolve_effect_value/3:
 defp resolve_effect_value(%{value: value} = effect, target, combat_state) when is_map(value) do
   context = build_effect_context(target, combat_state)
   %{effect | value: Game.Formula.resolve(value, context)}
 end
 defp resolve_effect_value(effect, _target, _combat_state), do: effect
 3. Add build_effect_context/2:
 defp build_effect_context(target, combat_state) do
   caster = CombatState.get_current_player(combat_state)
   {:ok, state_json} = Jason.encode(combat_state)
   {:ok, state_map} = Jason.decode(state_json)
   {:ok, caster_json} = Jason.encode(caster)
   {:ok, caster_map} = Jason.decode(caster_json)
   %{"caster" => caster_map, "target" => encode_target(target), "state" => state_map}
 end

 defp encode_target(target) when is_tuple(target),
   do: %{"position" => Tuple.to_list(target)}
 defp encode_target(target) do
   {:ok, json} = Jason.encode(target)
   {:ok, map} = Jason.decode(json)
   map
 end

 Step 3 — Update typespecs

 In each effect module, broaden value: integer() to value: integer() | map().

 Verification

 mix test test/game/combat/card_effects/damage_test.exs
 mix test test/game/card_test.exs
 mix test  # full suite to catch regressions

 Out of scope

 DB-persisted procedural values require changing BaseCard.Effect's value field from StringOrNumber
 (binary-only) to a type that accepts maps, plus a migration. Deferred.