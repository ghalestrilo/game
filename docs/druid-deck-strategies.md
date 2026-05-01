# Druid Deck Strategies

A design brainstorm for druid archetypes — what each strategy wants to do, what cards it needs, and what mechanics (existing or new) make it tick.

---

## Existing mechanics the druid can already exploit

| Mechanic | Card | Notes |
|----------|------|-------|
| Crowd control | Entangling Roots | Root for 2 turns + light damage |
| Heal over time | Rejuvenation | 2 heal + regen 3 — the druid's sustain baseline |
| Regen | Wild Growth | 3 heal + growth 2 — accelerated regen |
| Burn DoT | Moonfire | 3 damage + burn 2 — offensive DoT |
| AoE | Group Heal (cross-class) | 3 HP to all allies |
| Summon | Summon effect | Flavored as summoning beasts |

---

## Strategy 1: Wild Shape (Form transformation)

**Concept:** The druid transforms into different animal forms mid-combat, each unlocking a different set of cards and changing their base stats. Bear Form is tanky, Wolf Form is fast, Eagle Form is ranged. Switching forms is a strategic pivot — pick the form that counters what the enemy is doing right now.

**Wants:**
- Three distinct form status effects (`:bear_form`, `:wolf_form`, `:eagle_form`)
- Cards exclusive to each form (playable only in that form)
- A form-shift card (cheap or free) to pivot between forms
- Base stat changes on form shift (HP, movement range, AP)

**Key novel card ideas:**
- **Bear Form** (1 AP) — Shift to bear. Apply `bear_form`, remove other forms. Gain `shield: 5`. Movement range -1, but every melee card hits for +2.
- **Wolf Form** (1 AP) — Shift to wolf. Apply `wolf_form`. Gain 1 free movement tile. Cards cost 1 less AP (minimum 1).
- **Eagle Form** (1 AP) — Shift to eagle. Apply `eagle_form`. All cards gain range +3. Melee cards lose AoE.
- **Maul** (2 AP, Bear only) — Deal 10 damage to target and apply `armor_broken: 2`. Only playable in `bear_form`.
- **Pounce** (1 AP, Wolf only) — Move 3 tiles toward target. Deal 5 damage. Combines movement and damage with wolf mobility.
- **Dive Bomb** (3 AP, Eagle only) — Deal 12 damage from any range. Can only be played from 4+ tiles away.

**New mechanic needed:** Form status effects are mutually exclusive, same pattern as Barbarian Weapon Master stances. Form-based card gates in targeting rules (`caster_in_bear_form` alias). Stat modifiers on form shift (movement range, AP cost reduction) — these need to modify character attributes at form-shift time and restore them on form change, more complex than a simple status flag. Wolf Form's AP cost reduction could be a `cheap_cards` buff that modifies AP cost during `process_card`.

---

## Strategy 2: Nature's Wrath (Terrain control)

**Concept:** The druid reshapes the battlefield itself — placing forests that slow movement, thorned ground that damages anyone who steps on it, and sacred groves that buff allies. The map becomes an extension of the druid's deck. Enemies must navigate a hostile environment before they can even reach the druid.

**Wants:**
- Cards that modify tile terrain properties
- Terrain effects that trigger on entry (damage, slow, root)
- Cards that buff allies standing on nature terrain
- A way to chain terrain tiles together for zone control

**Key novel card ideas:**
- **Overgrowth** (1 AP) — Target a tile. It becomes `difficult terrain`: moving onto it costs 1 extra movement. Slows enemy approach.
- **Thorn Patch** (2 AP) — Target a tile. Any enemy that moves onto it takes 4 damage. Similar to Ranger Bear Trap but immediate damage rather than a root.
- **Sacred Grove** (2 AP) — Target a tile. Any ally who starts their turn on it heals 4 HP. Persistent buff aura, identical to Cleric's Consecrated Ground but healing-focused.
- **Wall of Thorns** (3 AP) — Place `thorn_patch` on 3 adjacent tiles simultaneously. A line of denial across a corridor.
- **Call of the Wild** (2 AP) — All allies on nature-terrain tiles gain +4 damage this turn. Rewards positioning allies on the druid's prepared ground.

**New mechanic needed:** Tile terrain modification — write a new terrain type (`difficult`, `thorn_patch`, `sacred_grove`) to `grid.tiles[position].terrain` as an effect. Entry triggers on `difficult` and `thorn_patch` fire in the move action validation in `process_action({:move, ...})`. `Sacred Grove` uses the same tile aura system as Cleric's Consecrated Ground.

---

## Strategy 3: Plague Bringer (Stacking DoT spread)

**Concept:** Stack burn and poison on every enemy on the board simultaneously, then let time do the work. The druid never deals direct damage — only applies DoTs, accelerates their ticking, and spreads them. By mid-game every enemy is melting from multiple sources at once.

**Wants:**
- AoE poison and burn application
- Cards that spread DoTs from one target to adjacent enemies
- Cards that accelerate DoT ticks (deal the next tick immediately without consuming it)
- Moonfire as the core single-target DoT starter

**Key novel card ideas:**
- **Spore Cloud** (2 AP) — Apply `poison: 2` to all enemies in range 2. AoE poison seed — covers multiple targets cheaply.
- **Contagion** (2 AP) — Copy all DoT effects from one target onto all adjacent enemies. The spread card — set up one target heavily, then explode outward.
- **Accelerate** (1 AP) — Trigger one tick of all DoT effects on target immediately (deal current DoT damage without decrementing the counter). Converts patient waiting into burst.
- **Raging Wildfire** (2 AP) — AoE `burn: 3` to all enemies. If any target already has burn, double their current burn value instead. Stacking burn synergy.
- **Death Blossom** (3 AP) — All enemies take damage equal to the sum of all their current DoT values simultaneously. The DoT cash-out — scales with how many ticks are loaded.

**New mechanic needed:** DoT tick logic (decrement and deal per tick) for both poison and burn — shared infrastructure, same pattern as the stealth tick in `setup_player_turn`. `Accelerate`'s immediate tick needs a one-shot version of that tick that doesn't decrement. `Death Blossom` sums all DoT values across all status types — needs a formula or effect that reads multiple status types from a single character.

---

## Strategy 4: Beast Caller (Diverse summon synergy)

**Concept:** Where the Ranger Beastmaster focuses on one or two upgraded companions, the druid summons a diverse menagerie — a tank bear, a fast wolf, a poisoning spider — each with different roles. Cards that synergize with having multiple different beast types on the field. The druid is a force multiplier for a diverse team composition.

**Wants:**
- Multiple distinct beast base classes (Bear, Wolf, Spider, Vine Horror)
- Cards that check the number of *different* beast types on the field
- Cards that command specific beast types (target "any wolf ally")
- A capstone card that is stronger for each unique beast type present

**Key novel card ideas:**
- **Summon Wolf** (2 AP) — Summons a Wolf (fast, low HP, applies bleed on hit).
- **Summon Bear** (2 AP) — Summons a Bear (slow, high HP, applies taunt passively).
- **Summon Spider** (1 AP) — Summons a Spider (fragile, applies poison on every attack).
- **Pack Leader** (2 AP) — All beast allies gain +3 damage and +1 AP this turn. A global buff for the menagerie.
- **Nature's Army** (3 AP) — Deal `4 × number_of_unique_beast_types` damage to all enemies. The diversity payoff — having Wolf + Bear + Spider = 12 damage AoE.

**Formula hook:** `number_of_unique_beast_types` needs a formula that extracts the `class` field from each ally in the queue, filters for beast classes, and counts unique values. The `reduce` operator in JsonLogic can handle deduplication. Beast classes need a shared tag (`beast: true` metadata) so the formula can identify them generically.

---

## Strategy 5: Cycle of Life (Regen stacking + HoT engine)

**Concept:** Stack heal-over-time effects until they generate more HP per turn than the enemy can remove. The druid wins a war of attrition — early turns are about stacking regen on every ally, mid-game the regen engine overwhelms the incoming damage, and the druid finishes with a large healing burst. Healing as inevitability.

**Wants:**
- Multiple regen sources to stack (Rejuvenation, Wild Growth as the starting point)
- Cards that multiply existing regen (double current regen stacks)
- Cards that convert regen into burst (spend regen stacks for immediate HP)
- A passive that triggers when regen fully heals a target (bonus reward)

**Key novel card ideas:**
- **Bloom** (1 AP) — Apply `regen: 2` to target. The cheapest regen application — stack multiple per turn.
- **Flourish** (1 AP) — Double the regen value on target (e.g., regen 2 → regen 4). No direct heal — pure multiplication.
- **Burst of Life** (2 AP) — Consume all regen stacks on target. Heal them for `3 × stacks_consumed` immediately. Converts patient regen into burst healing when the situation is critical.
- **Overheal** (2 AP) — Heal target for 6. If they are already at full HP, apply `shield: 6` instead. Rewards keeping allies topped up — the excess heal converts to mitigation.
- **Ancient Growth** (3 AP) — Apply `regen: 5` to all allies. For 2 turns, regen ticks twice per turn end (double tick rate). The regen flood card — by the end of the next two turns every ally has healed 20+ HP.

**New mechanic needed:** Regen tick logic at turn end — same pattern as poison/burn ticks, but applying positive `apply_healing` instead of damage. `Flourish` needs a multiply operation on a specific status effect value. `Burst of Life` consumes all regen stacks (same consume-all pattern as Barbarian's Shatterpoint). `Ancient Growth`'s double-tick rate needs a `regen_double_tick` status that fires the regen hook twice in `setup_player_turn`.

---

## Mechanic summary: what's needed to unlock these

| Mechanic | Status | Strategy |
|----------|--------|----------|
| Form status effects (mutually exclusive) | Novel, shared pattern with Barbarian stances | Wild Shape |
| `caster_in_[form]` formula aliases | Novel, trivial (`some` over status_effects) | Wild Shape |
| AP cost reduction buff (`cheap_cards`) | Novel — modifies AP deduction in `process_card` | Wild Shape |
| Tile terrain modification effect | Novel — write terrain type to `grid.tiles[pos]` | Nature's Wrath |
| Entry trigger on terrain tiles | Novel — checked in `process_action({:move, ...})` | Nature's Wrath |
| Tile aura (heal/buff on turn start) | Novel, shared with Cleric's Consecrated Ground | Nature's Wrath |
| DoT tick logic (poison + burn) | Needs implementation, shared with Ranger + Necromancer | Plague Bringer |
| Immediate DoT tick without decrement | Novel variant of tick logic | Plague Bringer |
| DoT sum formula across all effect types | Novel — read multiple status types simultaneously | Plague Bringer |
| Beast class tags | Novel content metadata | Beast Caller |
| `number_of_unique_beast_types` alias | Novel formula using `reduce` for deduplication | Beast Caller |
| Regen tick logic at turn end | Needs implementation, symmetric with poison tick | Cycle of Life |
| Status effect value multiplication | Novel — `Flourish` doubles a specific status value | Cycle of Life |
| Consume-all-of-type | Novel, shared with Barbarian + Necromancer | Cycle of Life |
| Double-tick-rate buff | Novel — fires regen hook twice in `setup_player_turn` | Cycle of Life |
