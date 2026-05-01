# Mage Deck Strategies

A design brainstorm for mage archetypes — what each strategy wants to do, what cards it needs, and what mechanics (existing or new) make it tick.

The mage's distinction from the Sorcerer: where the Sorcerer is wild and instinctive, the Mage is precise and calculated. Resource management, spell sequencing, and perfect information. Every card play is deliberate. The ceiling is lower but the floor is higher — less variance, more control.

---

## Existing mechanics the mage can already exploit

| Mechanic | Card | Notes |
|----------|------|-------|
| High single-target damage | Fireball (8), Lightning Bolt (7) | The mage's primary damage output |
| Crowd control | Lightning Bolt (stun 1) | Single-target lockdown |
| Slow | Icicle | Movement reduction |
| AoE | Arcane Explosion | 6 damage to all nearby |
| Shield + draw | Mana Shield | The mage's self-defense + cycling tool |

---

## Strategy 1: Spell Sequencer (Chained spell combos)

**Concept:** Cards are designed to be played in specific sequences — each spell leaves the target in a state that the next spell exploits. Icicle slows the target (they can't escape); Fireball deals bonus damage against slowed targets; Lightning Bolt stuns after fire debuffs. The mage plans two or three cards ahead, executing a rehearsed combo.

**Wants:**
- Elemental status effects applied by spells (slow, burning, chilled)
- Cards that deal bonus damage against targets with specific statuses
- A way to chain all three spells in a single turn (AP generation or cost reduction)
- Cards that set up status without dealing damage (pure debuff appliers)

**Key novel card ideas:**
- **Frost Nova** (1 AP) — Apply `chilled: 2` to target (no damage). Pure setup — slows the target and enables Shatter.
- **Shatter** (2 AP) — Deal 10 damage to target. If they are `chilled`, deal 16 instead and remove `chilled`. The combo finisher for the ice chain.
- **Pyro Combo** (1 AP) — If target is `burning`, deal 5 damage and remove `burning`. Otherwise deal 2 damage and apply `burning: 1`. Self-contained mini-chain: first cast applies burn, second cast cashes it in.
- **Arc Flash** (2 AP) — Deal 6 damage. If target was already damaged by a spell this turn (any spell), also apply `stun: 1`. Requires playing a damage spell first — punishes aggressive sequential play.
- **Mana Flow** (1 AP) — Reduce the cost of the next spell played this turn by 2 AP (minimum 0). The sequencing enabler — makes a 3-card combo fit into a 3 AP turn.

**Formula hook:** Status checks on target (`chilled`, `burning`) use `some` over `target.status_effects` — same pattern as `caster_is_hidden`. `Arc Flash` needs a `damaged_this_turn` flag on the target (incremented in `apply_damage`). `Mana Flow` applies a `cost_reduction: 2` status read in the AP deduction step of `process_card`.

---

## Strategy 2: Arcane Scholar (Spell slot management)

**Concept:** The mage has a finite number of spell slots per game (not per turn). Powerful spells consume a slot when cast; once all slots are used, only cantrips (0-slot spells) remain. Managing the slot economy — knowing when to spend a slot and when to conserve — is the entire strategy. Mid-game the mage is weakest; early and late are the power peaks.

**Wants:**
- A `spell_slots` counter (starts at 5, consumed by slot-requiring spells)
- Slot-costing and slot-free (cantrip) card categories
- Cards that restore spell slots (rare, expensive)
- Cantrips that are weak but infinitely replayable as the late game fallback

**Key novel card ideas:**
- **Arcane Missile** (1 AP, cantrip) — Deal 3 damage. No spell slot cost. The infinite fallback — always playable.
- **Major Fireball** (2 AP, 1 slot) — Deal 14 damage. Consumes 1 spell slot. The power spell — dramatically stronger than a cantrip, but finite.
- **Arcane Recovery** (2 AP) — Restore 2 spell slots. The recovery card — use once when running low.
- **Spell Mastery** (1 AP) — Designate one card in hand. That card costs 0 spell slots for the rest of the game. Study a spell deeply enough and it becomes permanent.
- **Cantrip Cascade** (2 AP) — Play all cantrips in your hand for free simultaneously. The late-game burst when slots are exhausted — floods the target with weak spells at once.

**New mechanic needed:** `spell_slots` as a secondary resource on the character struct (alongside `ap` and sorcery points). Cards with `slot_cost: 1` consume from this pool in `process_card` before effects fire. Gate: if `spell_slots == 0` and card has `slot_cost > 0`, card cannot be played (targeting rule). `Cantrip Cascade` needs a loop that plays all matching cards in hand sequentially in one action.

---

## Strategy 3: Illusionist (Misdirection and duplication)

**Concept:** The mage creates illusions of themselves and their allies — fake targets that absorb hits and confuse enemy targeting. Combine with card-duplication effects to appear to play more cards than actually exist. The opponent never knows which effect is real and which is illusion until it's too late.

**Wants:**
- Illusion summons (decoys that absorb exactly one hit then disappear)
- Cards that duplicate themselves (play the card, add a copy to hand)
- Misdirection effects (make the enemy waste attacks on illusions)
- Cards whose effects are hidden until triggered (face-down effects)

**Key novel card ideas:**
- **Mirror Image** (1 AP) — Summon 2 Illusion tokens on adjacent tiles. Each absorbs the next attack targeting the mage, then disappears. Requires a new `illusion` flag on summoned characters — they have 1 HP, no cards, and dissolve on taking any damage.
- **Echo Spell** (2 AP) — Play a card from hand normally. Add a copy of that card to your hand. The card is not consumed — you keep it. One-time duplication.
- **Phantom Strike** (1 AP) — Deal 5 damage. 50% chance the target cannot tell whether this was real — apply `confused: 1` (they cannot target the mage on their next action, choosing randomly instead).
- **Displacement** (1 AP) — Swap the mage's position with an Illusion token on the board. The enemy attacked the illusion position; the mage is now somewhere else.
- **Grand Illusion** (3 AP) — Duplicate every card currently in hand. For 1 turn, the mage appears to have twice as many options as they actually do. Overwhelm decision-making.

**New mechanic needed:** `illusion` flag on summoned character structs — checked in `check_target_death` to silently remove on any damage rather than going to graveyard. `Echo Spell` needs a card-duplication step in `process_card` that skips the discard step for that one card. `Displacement` requires a two-character position swap, modifying both `current_turn.player` position and the illusion token's grid tile simultaneously.

---

## Strategy 4: Arcane Battery (Mana accumulation)

**Concept:** The mage spends the first two or three turns doing almost nothing — drawing cards and accumulating `mana_charges` — then unleashes everything in one catastrophic turn where every card is free or discounted. Patience as a mechanic. Opponents who don't kill the mage during the setup window face a turn of unrestricted spell spam.

**Wants:**
- Cards that generate `mana_charges` without dealing damage
- Cards whose cost is paid in `mana_charges` instead of AP (or reduced by them)
- A "discharge" turn enabler that converts the battery into free cards
- Draw engines to assemble the right spells for the payoff turn

**Key novel card ideas:**
- **Mana Siphon** (1 AP) — Gain 2 `mana_charges`. Draw 1 card. Pure battery-charging action — costs AP now, pays out later.
- **Arcane Conduit** (0 AP) — Gain 1 `mana_charge`. No draw. The zero-cost trickle charge.
- **Discharge** (1 AP) — For this turn, all cards can be paid with `mana_charges` at 2 charges per 1 AP. The payoff enabler — 10 mana_charges = 5 free AP worth of spells.
- **Chain Lightning** (3 AP or 6 charges) — Deal 6 damage to target, then 5 to a random other enemy, then 4 to another, cascading until 0. The battery's payoff spell — massive multi-target damage.
- **Mana Shield** (already exists) — Recontextualized: in this deck it's both defense and a `mana_charge` generator (grant 1 charge when shield absorbs a hit).

**Formula hook:** `mana_charges` as a stacking status. `Discharge` applies a `mana_payment_mode` flag on `current_turn` analogous to Blood Mage's `blood_price_active`. `Chain Lightning` requires a cascading effect loop — resolve the first hit, then pick a random remaining target, repeat.

---

## Strategy 5: Counterspell Mage (Reactive control)

**Concept:** The mage doesn't take their own turn aggressively — they hold up reactive spells that fire on the enemy's turn. If an enemy plays a card, the mage interrupts it. If an enemy moves within range, the mage fires an opportunity attack. Patience and positioning. The deck is 40% reactive traps and 60% fall-through damage for when nothing to counter presents itself.

**Wants:**
- A "hold" or "readied action" mechanic — set a trigger condition at the start of the turn and fire if it's met
- Counterspell cards that negate an incoming card effect
- Opportunity attack cards that deal damage when an enemy enters range
- A way to skip the mage's turn to hold reactions without wasting the opportunity

**Key novel card ideas:**
- **Counterspell** (2 AP) — Readied action: if any enemy plays a card before the mage's next turn, negate its effect entirely. The mage skips their offense to deny one enemy play.
- **Force Cage** (2 AP) — Readied action: if any enemy moves within 3 tiles of the mage, root them for 2 turns and deal 5 damage. Opportunity attack — punish approach.
- **Arcane Ward** (1 AP) — Readied action: if any enemy targets the mage with a card before the mage's next turn, the mage takes half damage and counters with 4 damage to the attacker.
- **Prepared Spell** (1 AP) — Hold a specific card face-down. On the mage's next turn, it plays for free at the start before drawing. Pre-loading a turn-opener.
- **Nullify** (0 AP) — Negate the most recent card effect that was applied this turn (by anyone). An immediate interrupt rather than a readied action — the "undo" button.

**New mechanic needed:** Readied action system — at end of turn (rather than beginning), the mage may set a `readied_action` field on `current_turn` with a trigger condition and an effect. During other characters' turns, after each action resolves, the system checks all active readied actions. This is the most significant new system in any of these docs — a reactive action layer on top of the existing turn-based loop. `Nullify` is simpler: track `last_applied_effect` on combat state and reverse it.

---

## Mechanic summary: what's needed to unlock these

| Mechanic | Status | Strategy |
|----------|--------|----------|
| Elemental status effects (chilled, burning) | Needs implementation, shared with Sorcerer | Spell Sequencer |
| `damaged_this_turn` flag on character | Novel — set in `apply_damage`, cleared at turn start | Spell Sequencer |
| `cost_reduction` buff status | Novel — read in AP deduction step of `process_card` | Spell Sequencer |
| `spell_slots` secondary resource | Novel — new Character field, shared concept with Sorcerer's `sorcery_points` | Arcane Scholar |
| `Cantrip Cascade` bulk-play loop | Novel — play multiple hand cards in one action | Arcane Scholar |
| `illusion` flag on summoned characters | Novel — dissolve on any damage, skip graveyard | Illusionist |
| `Echo Spell` card duplication | Novel — skip discard for one card in `process_card` | Illusionist |
| Two-character position swap (Displacement) | Novel positional effect | Illusionist |
| `mana_charges` stacking status | Novel secondary resource as status, shared pattern with `sorcery_points` | Arcane Battery |
| `mana_payment_mode` turn flag | Novel, same pattern as Blood Mage `blood_price_active` | Arcane Battery |
| Cascading chain effect loop | Novel — resolve → pick next target → repeat | Arcane Battery |
| Readied action system | Novel — trigger conditions checked during other characters' turns | Counterspell Mage |
| `last_applied_effect` tracking | Novel — reverse-last-effect for Nullify | Counterspell Mage |
