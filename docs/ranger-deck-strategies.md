# Ranger Deck Strategies

A design brainstorm for ranger archetypes — what each strategy wants to do, what cards it needs, and what mechanics (existing or new) make it tick.

---

## Existing mechanics the ranger can already exploit

| Mechanic | Card | Notes |
|----------|------|-------|
| Ranged damage | Shot, Snipe | Range 5–6, attacks from a safe distance |
| Multi-strike | Multishot | 3 hits × 3 damage at range 4 |
| Poison | Poison Arrow | 3 damage + poison DoT |
| AoE damage | Arcane Explosion, Cleave (cross-class) | Hits multiple enemies |
| Execute scaling | Execute | Bonus damage on low-HP targets |
| Movement | Evade | Reposition to maintain range advantage |

---

## Strategy 1: Sniper (Maximum range, minimum exposure)

**Concept:** Stay at the maximum possible distance from every enemy. Every card either deals damage from extreme range or punishes enemies for closing in. If an enemy gets adjacent, use movement cards to re-establish distance before shooting again.

**Wants:**
- Snipe (range 6) as the primary win condition
- Cheap filler shots while Snipe is on cooldown (Shot at range 5)
- Movement cards to maintain distance
- Cards that deal bonus damage based on how far away the target is

**Key novel card ideas:**
- **Longshot** (2 AP) — Deals damage equal to the hex distance to the target (formula: cube distance between `caster.position` and `target.position`). Minimum range 3, rewards extreme positioning.
- **Warning Shot** (1 AP) — Deals no damage. Applies a `marked` status to target: if they move closer next turn, they take 6 damage automatically. Discourages gap-closing.
- **Kite** (1 AP) — Move 2 tiles away from the nearest enemy (auto-direction). Draw 1 card.
- **Steady Aim** (1 AP) — Buff: if the ranger does not move this turn, their next shot deals double damage. Rewards patience.

**Formula hook:** Hex distance between two positions needs a custom operator or a pre-computed `distance_to_target` variable injected into the formula context. `Warning Shot` needs a new triggered/reactive status effect (fires on enemy movement).

---

## Strategy 2: Poison Skirmisher (DoT + mobility)

**Concept:** Apply poison to as many enemies as possible, then keep moving to avoid retaliation while the poison ticks them down. Win by outlasting rather than out-damaging.

**Wants:**
- Poison Arrow as the core applier
- AoE poison spread (hit multiple targets)
- Movement cards to create hit-and-run turns
- Cards that amplify poison stacks already on a target

**Key novel card ideas:**
- **Toxic Volley** (2 AP) — AoE poison application at range 3. Applies `poison: 1` to all enemies in radius. Lower damage than Poison Arrow, but hits everything.
- **Venomous Shot** (1 AP) — If the target already has poison, this shot deals bonus damage equal to current poison stacks. Rewards stacking first.
- **Infected Wound** (2 AP) — Deals light damage and doubles the target's current poison value. Pairs with Poison Arrow for an exponential spike.
- **Smoke Arrow** (1 AP) — AoE discard on all enemies in a small radius (cough, distraction). Applies `blind: 1` (reduces their range on next attack) as a new status effect.

**New mechanic needed:** Poison tick at turn end (same implementation pattern as the stealth tick — decrement `value` by 1 each `setup_player_turn`, deal `value` damage first). Blind as a status that reduces a card's effective range on next use.

---

## Strategy 3: Trapper (Board control + zone denial)

**Concept:** Place traps on tiles before enemies reach them. Enemies who move into trapped tiles trigger the effect automatically. Combine with movement-denial (roots, slows) to funnel enemies into the traps.

**Wants:**
- A new "trap" card effect type — places a trigger on a tile rather than acting immediately
- Crowd control to force enemies toward trapped zones (root, slow)
- Cards that reward standing still (set traps, then wait)

**Key novel card ideas:**
- **Bear Trap** (1 AP) — Target a tile. Places a `trap: root` token. The next enemy that steps on that tile is rooted for 2 turns. Costs no range since you're targeting a tile, not a character.
- **Explosive Trap** (2 AP) — Places a `trap: damage(8)` token on a tile. Triggers on enemy entry.
- **Hunter's Mark** (1 AP) — Applies a `marked` status that makes the target's movement visible to the ranger (no mechanical effect yet, but telegraphs positioning) and increases damage taken from traps by 50%.
- **Lure** (1 AP) — Forces a target enemy to move 1 tile toward the ranger. Useful for pulling enemies into placed traps.

**New mechanic needed:** Trap tokens on grid tiles — a new tile property that stores a pending effect and a trigger condition (on_enter). This is a bigger system addition but fits naturally into the existing hex grid tile structure (`terrain`, `occupied_by` → add `trap`).

---

## Strategy 4: Volley Archer (Multi-hit tempo)

**Concept:** Fire as many arrows as possible per turn using cheap multi-strike cards. Each individual hit is weak, but the volume overwhelms shields and triggers on-hit effects repeatedly. Multishot is the seed; build around it.

**Wants:**
- Multishot as the engine
- Cards that trigger a bonus effect each time they hit (on-hit effects)
- Ways to increase the number of hits per card (multi scaling)
- Cards that draw more cards to keep the hand full

**Key novel card ideas:**
- **Arrow Rain** (3 AP) — Fires 5 projectiles each dealing 2 damage at a single target. High AP cost but maximum hit count for on-hit synergies.
- **Puncture** (1 AP) — Deals 2 damage. If this kills a shield stack, draw 1 card. Incentivizes targeting shielded enemies.
- **Fletchling** (1 AP) — Draw 2 cards. Can only be played if you've dealt damage this turn. Rewards aggressive play, keeps the hand flowing.
- **Hail of Arrows** (2 AP) — AoE multi-strike: deals 2 hits of 2 damage to all enemies in range 3. Extends the volley identity to multiple targets.

**Formula hook:** On-hit effects (draw on hit, bonus damage on Nth hit) need a hit counter tracked during card resolution — or each multi-strike hit resolves as a separate effect loop iteration, which the existing `multi` field already suggests.

---

## Strategy 5: Beastmaster (Summon + command)

**Concept:** Summon animal companions that fight independently while the ranger provides support fire from range. Outnumber the enemy by controlling multiple units. The ranger's personal damage is secondary — the board presence wins.

**Wants:**
- Summon effect (already implemented) for animal companions
- Cards that buff summoned allies
- Cards that command specific summons (target an ally, give them AP or a free attack)
- A way to distinguish summoned animals from other team members in formulas

**Key novel card ideas:**
- **Call Wolf** (2 AP) — Summons a Wolf companion (new base class: low HP, high movement, 1 AP melee attack). Inherits ranger's team.
- **Call Hawk** (2 AP) — Summons a Hawk companion (new base class: ranged harasser, applies `blind` on hit).
- **Pack Tactics** (1 AP) — Target an ally. They immediately take one free action (draw 1 card, or trigger a basic attack if AI-controlled). Synergizes with summoned units.
- **Coordinated Strike** (2 AP) — Both the ranger and one adjacent ally deal their basic attack damage to the same target simultaneously. Requires a summon to be in range.
- **Recall** (1 AP) — Remove a friendly summon from the board and draw 2 cards. Lets you cycle summons strategically or avoid giving the enemy an easy kill.

**Formula hook:** `caster.team` is already tracked. A `has_summon_on_team` alias could check whether the queue contains any unit with `class == "wolf"` on the caster's team. Pack Tactics would need a new `grant_ap` or `free_action` effect targeting a specific ally.

---

## Mechanic summary: what's needed to unlock these

| Mechanic | Status | Strategy |
|----------|--------|----------|
| Long-range damage (Shot, Snipe) | **Done** | Sniper |
| Poison DoT tick at turn end | Needs implementation (same pattern as stealth tick) | Poison Skirmisher |
| `distance_to_target` formula variable | Novel — inject into effect context | Sniper |
| Reactive/triggered status (Warning Shot) | Novel status type | Sniper |
| Blind status effect | Novel | Poison Skirmisher |
| Trap tokens on grid tiles | Novel tile property + trigger system | Trapper |
| Lure / forced movement | Novel effect type | Trapper |
| Multi-strike on-hit hooks | Needs implementation in multi-strike loop | Volley Archer |
| Animal companion base classes | Novel content (Wolf, Hawk) | Beastmaster |
| `grant_ap` / free-action effect | Novel effect type | Beastmaster |
| `has_summon_on_team` formula alias | Novel alias, no code changes | Beastmaster |
