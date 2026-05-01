# Rogue Deck Strategies

A design brainstorm for rogue archetypes — what each strategy wants to do, what cards it needs, and what mechanics (existing or new) make it tick.

---

## Existing mechanics the rogue can already exploit

| Mechanic | Card | Notes |
|----------|------|-------|
| Stealth | Shadowstrike, Backstab | Backstab doubles damage (3→10) while hidden |
| Poison | Poison Dagger | Damage-over-time, not yet implemented as tick logic |
| Move | Evade | Free repositioning + implicit dodge |
| Multi-strike | (Multishot pattern) | Hit multiple times with one card |
| Discard | Discard effect | Force opponent to lose hand cards |
| Execute scaling | Execute | Bonus damage on low-HP targets |

---

## Strategy 1: Shadow Assassin (Stealth burst)

**Concept:** Get into stealth, then spend the hidden turns stacking AP or positioning, then unload a single Backstab for a one-shot combo.

**Wants:**
- Multiple stealth sources (Shadowstrike applies stealth *and* deals damage)
- Cheap card draw to find Backstab while hidden
- Movement cards to close distance during stealth turns

**Key novel card ideas:**
- **Vanish** (1 AP) — Pure stealth with no damage. Stealth value 2. Sets up Backstab without committing to Shadowstrike's 2 AP.
- **Ambush** (2 AP) — Only playable while hidden. Deals damage *and* re-applies stealth, letting you stay hidden after striking.
- **Shadow Step** (1 AP) — Teleport to a tile adjacent to target. Playable only while hidden. Costs no movement.

**Formula hook:** Backstab already uses `caster_is_hidden`. Ambush and Shadow Step can use the same alias as a targeting rule gate.

---

## Strategy 2: Bleed & Poison (DoT accumulator)

**Concept:** Stack damage-over-time effects that tick every turn end, then skip turns or hide to let the poison kill the target while staying safe.

**Wants:**
- Poison (Poison Dagger) as the primary damage source
- New "bleed" effect (similar to poison but stacks additively)
- Stealth as a survival tool — hide while DoTs do the work
- Cards that amplify DoT stacks

**Key novel card ideas:**
- **Hemorrhage** (1 AP) — Applies `bleed: 2`. Cheap to play multiple times to stack.
- **Rupture** (2 AP) — Deals damage equal to the target's current bleed stacks (via formula: `%{"var" => "target.bleed"}`), then removes bleed.
- **Envenom** (1 AP) — Doubles the target's current poison value. No direct damage.
- **Toxic Smoke** (2 AP) — AoE poison application. Hits all nearby enemies with `poison: 1`.

**New mechanic needed:** Bleed as a second DoT type that stacks (each application adds to `value` rather than overwriting). Poison ticks could share the same tick-down logic added for stealth.

---

## Strategy 3: Evasion Tank (Dodge & counter)

**Concept:** Use Evade aggressively to become untargetable or to reposition after each attack, making the rogue hard to pin down. Cards that reward movement.

**Wants:**
- Dodge/Evade mechanic (Evade card exists but dodge effect is unimplemented)
- Cards that deal more damage based on how far the caster moved this turn
- Cards that reward being attacked (counter)

**Key novel card ideas:**
- **Riposte** (1 AP) — Gives the caster a counter buff: the next time they take damage this turn, the attacker takes the same amount back.
- **Flurry** (2 AP) — Deals damage equal to the number of tiles moved this turn (formula: distance between `caster.starting_position` and `caster.position`).
- **Smoke Bomb** (2 AP) — AoE discard on all adjacent enemies (forces them to discard 1 card each). Creates chaos, buys a turn.
- **Acrobatics** (0 AP) — Draw 1 card if you moved this turn. Rewards active repositioning.

**Formula hook:** `current_turn.starting_position` is already stored on the turn. A `tiles_moved` alias could compute hex distance between `caster.starting_position` and `caster.position` using the cube coordinate formula.

---

## Strategy 4: Hand Disruption (Control rogue)

**Concept:** Force opponents to discard cards, cycling their draw pile faster than they can act. Win by attrition — the enemy runs out of good options.

**Wants:**
- The Discard card effect (already implemented)
- Cards that get stronger when the opponent has fewer cards in hand
- Stealth to avoid retaliation while dismantling the opponent's hand

**Key novel card ideas:**
- **Pickpocket** (1 AP) — Steal 1 random card from target's hand, add it to your hand.
- **Mug** (2 AP) — Deal light damage + discard 2 cards from target's hand.
- **Exploit Weakness** (2 AP) — Deals damage equal to `(5 - target hand size) * 2`. Punishes an empty hand.
- **Distraction** (1 AP) — Target skips drawing at the start of their next turn (new `skip_draw` status effect).

**Formula hook:** `target.cards.hand` length is already available in the formula context. `Exploit Weakness` is a straightforward `%{"*" => [%{"-" => [5, %{"var" => "target.cards.hand.length"}]}, 2]}`.

---

## Strategy 5: Glass Cannon (Tempo rush)

**Concept:** Spend 0 AP on defense, run a lean deck of only high-damage cards, and kill before the opponent can respond. Every card is a threat.

**Wants:**
- Low-cost high-damage cards (Backstab at 1 AP is already the template)
- Cards that generate extra AP on kill
- Discard-based cycling (discard hand, draw better cards)
- No shields, no heals

**Key novel card ideas:**
- **Adrenaline** (0 AP) — Draw 2 cards, discard 1. Digs for the kill card.
- **Finishing Blow** (1 AP) — Can only target enemies below 30% HP. Deals 15 damage. Seeded with formula gate on targeting rule.
- **On the Edge** (passive / buff effect) — While below 50% HP, all damage cards deal +3. References `caster_below_half` alias (easy to add alongside `target_below_half`).
- **Death Mark** (2 AP) — Applies a status that causes the next damage instance on the target to be doubled. A delayed multiplier.

---

## Mechanic summary: what's needed to unlock these

| Mechanic | Status | Strategy |
|----------|--------|----------|
| Stealth tick + dispel on play | **Done** | Shadow Assassin, Bleed, Glass Cannon |
| Poison / bleed tick at turn end | Needs implementation (same pattern as stealth tick) | Bleed & Poison |
| Dodge / untargetable | Effect stub exists, unimplemented | Evasion Tank |
| Counter (reflect damage) | Novel | Evasion Tank |
| Pickpocket / steal card | Novel | Hand Disruption |
| `tiles_moved` formula alias | Novel alias, no code changes | Evasion Tank |
| `caster_below_half` alias | Novel alias, trivial to add | Glass Cannon |
| Targeting rule gates on HP thresholds | Formula system already supports this | Glass Cannon |
| Death Mark (damage multiplier buff) | Novel status effect | Glass Cannon |
