# Barbarian Deck Strategies

A design brainstorm for barbarian archetypes — what each strategy wants to do, what cards it needs, and what mechanics (existing or new) make it tick.

---

## Existing mechanics the barbarian can already exploit

| Mechanic | Card | Notes |
|----------|------|-------|
| Basic melee | Strike | 5 damage for 1 AP — the barbarian's bread and butter |
| AoE melee | Cleave, Whirlwind | Hits multiple enemies; Whirlwind at 7 AoE is the current ceiling |
| Execute scaling | Execute | Bonus damage on low-HP targets, natural finisher |
| Shield | Block, Defend | Available but ideologically wrong for most barbarian archetypes |
| Movement | Evade (cross-class) | Close distance fast |

---

## Strategy 1: Rage Engine (Missing HP = more damage)

**Concept:** The barbarian gets stronger the more wounded they are. Every point of HP lost is a point of fury gained. Cards scale off missing HP or have conditionals that unlock below certain thresholds. The opponent faces a dilemma: keep hitting a barbarian who gets more dangerous the closer they are to death, or stop and let them recover.

**Wants:**
- Cards that scale damage with `caster_missing_hp` (alias already seeded)
- Cards that unlock at low HP thresholds (< 50%, < 25%)
- A way to deliberately take damage to fuel the engine
- High sustain via lifesteal or regen to stay alive in the danger zone

**Key novel card ideas:**
- **Bloodlust** (1 AP) — Deal damage equal to your missing HP. Formula: `%{"alias" => "caster_missing_hp"}`. Pure rage conversion.
- **Berserker's Fury** (2 AP) — Deal 5 damage. If the caster is below 50% HP, deal 10 instead. The conditional gate is `caster_below_half` (trivial alias to add).
- **War Cry** (1 AP) — Buff: for this turn, all damage cards deal `+1` per 3 missing HP. Stacks with Bloodlust for a compounding turn.
- **Undying Rage** (0 AP) — Reactive: if the barbarian would die this turn, they survive at 1 HP and gain 2 AP instead. One-time trigger — the berserk threshold.

**Formula hook:** `caster_missing_hp` already seeded. `caster_below_half` is a trivial companion alias. `Undying Rage` shares the "survive at 1 HP" mechanic with the Necromancer's `Undying Will` — same implementation hook in `check_target_death`.

---

## Strategy 2: Ground Shaker (AoE dominance)

**Concept:** Every card hits multiple enemies. Never single-target, always AoE. The barbarian wades into the middle of enemy formations and explodes outward. Positioning is everything — move to maximise adjacency before the big swings.

**Wants:**
- AoE damage on most cards (Cleave, Whirlwind as the template)
- Movement cards to reach the center of enemy clusters
- Cards whose AoE damage scales with the number of targets hit
- A "charge" mechanic to close distance and immediately deal AoE damage on arrival

**Key novel card ideas:**
- **Earthquake** (3 AP) — Deal 5 damage to all characters on the board, allies included. No range restriction — the whole battlefield shakes.
- **Charge** (2 AP) — Move up to 4 tiles in a straight line. Deal 6 damage to the first enemy in the path and knock them back 1 tile. Combines movement and damage.
- **Slam** (2 AP) — Deal 3 damage to all adjacent enemies and push each back 1 tile. Creates space after wading in.
- **Ground Pound** (2 AP) — Deal `2 × number of adjacent enemies` damage to all adjacent enemies. Scales with how surrounded the barbarian is — reward for being outnumbered.

**Formula hook:** `number_of_adjacent_enemies` needs a formula filtering the queue by team and distance ≤ 1 from `caster.position` — same infrastructure as the Monk's `number_of_adjacent_allies`. Knockback needs a new positional effect type that moves the target 1 tile away from the caster.

---

## Strategy 3: Juggernaut (Unstoppable momentum)

**Concept:** The barbarian cannot be stopped, slowed, or displaced once moving. Build a deck around maintaining momentum — each turn the barbarian moves and attacks, stacking a `momentum` counter that buffs the next attack. Stopping breaks the chain; keeping it going becomes a win condition.

**Wants:**
- Cheap movement cards to always have a move available
- Cards that check whether the barbarian moved this turn (`tiles_moved` alias)
- A stacking momentum counter that grows each consecutive turn the barbarian attacks
- Cards that reset or break enemy crowd-control to keep the chain alive

**Key novel card ideas:**
- **Unstoppable** (1 AP) — Remove all movement-restricting status effects (root, slow, stun) from self. Draw 1 card.
- **Momentum Strike** (1 AP) — Deal `3 + momentum_stacks` damage. Gain 1 momentum stack. The momentum counter lives as a stacking status effect.
- **Headlong Rush** (2 AP) — Move 3 tiles toward target. Deal `4 + (2 × tiles_moved this turn)` damage on arrival. Rewards a full movement turn before playing this.
- **Breaking Point** (3 AP) — Spend all momentum stacks. Deal `4 × stacks_spent` damage to all adjacent enemies. The momentum cash-out card — save 4–5 stacks for a board-clearing burst.

**Formula hook:** `momentum_stacks` reads `caster.status_effects` for a stacking `momentum` entry, same pattern as `soul_shards` in the Necromancer. `tiles_moved` alias shared with Ranger and Monk. `Breaking Point` needs a consume-all-of-type operation on status effects.

---

## Strategy 4: Weapon Master (Stance switching)

**Concept:** The barbarian cycles between two stances — Axe (offense) and Shield (defense) — by playing stance cards. Each stance unlocks a different set of bonus effects on other cards. Playing an axe card while in Shield stance does nothing special; in Axe stance it deals bonus damage. This creates a rhythm of reading the board and switching stances reactively.

**Wants:**
- Two stance status effects (`:axe_stance`, `:shield_stance`) with mutually exclusive application
- Cards that check current stance via `caster.status_effects` and branch behavior
- Cheap stance-switchers to allow mid-turn pivots
- Payoff cards that are dramatically better in the right stance

**Key novel card ideas:**
- **Take Up Axe** (0 AP) — Apply `axe_stance`. Remove `shield_stance` if present. The free stance pivot.
- **Take Up Shield** (0 AP) — Apply `shield_stance`. Remove `axe_stance` if present.
- **Wild Swing** (1 AP) — In `axe_stance`: deal 8 damage. In `shield_stance`: deal 3 damage. Formula: `%{"if" => [%{"alias" => "caster_in_axe_stance"}, 8, 3]}`.
- **Iron Fortress** (1 AP) — In `shield_stance`: apply `shield: 8`. In `axe_stance`: apply `shield: 2`.
- **Counter Charge** (2 AP) — Only playable in `shield_stance`. The next time you take damage this turn, immediately deal that amount back to the attacker and switch to `axe_stance`.

**Formula hook:** `caster_in_axe_stance` and `caster_in_shield_stance` are aliases that use `some` over `caster.status_effects` checking `type === "axe_stance"` — same pattern as `caster_is_hidden`. Stance cards cost 0 AP, similar to Monk's Gale Step.

---

## Strategy 5: Skullcrusher (Armor shred + execute)

**Concept:** Stack an `armor_broken` debuff on a target across multiple turns to reduce their effective shield and HP, then finish with a high-damage execute. The barbarian doesn't burst — they methodically dismantle the target's defenses before landing the killing blow. Strong against tanky, shielded enemies.

**Wants:**
- A stacking armor shred debuff that reduces shield value and/or incoming damage reduction
- Cards that check whether the target is armor-broken (for bonus effects)
- Execute-style finishers that scale off how broken the target's armor is
- Enough sustain to survive the multi-turn setup window

**Key novel card ideas:**
- **Armor Crush** (1 AP) — Deal 3 damage. Apply `armor_broken: 1` (each stack reduces the target's shield by 1 when they next apply shield, and increases damage taken by 1).
- **Rend** (2 AP) — Deal 4 damage. Apply `armor_broken: 3` in one hit. Faster stacking at higher AP cost.
- **Exposed Strike** (2 AP) — Can only target characters with `armor_broken` stacks. Deal `8 + (2 × armor_broken_stacks)` damage. The payoff card — scales directly with prior investment.
- **Shatterpoint** (3 AP) — Remove all `armor_broken` stacks from target. Deal `6 × stacks_removed` damage. The execute finisher — cash out 4–5 stacks for devastating single-target damage.
- **War Stomp** (2 AP) — AoE: apply `armor_broken: 1` to all adjacent enemies simultaneously. Enables the strategy against multiple targets.

**Formula hook:** `target_armor_broken_stacks` alias reads `target.status_effects` for the `armor_broken` entry value — same `some` pattern as other status aliases. `armor_broken` modifies the shield application step and the `apply_damage` pipeline, similar to `vulnerable` from the Monk Pressure Point doc.

---

## Mechanic summary: what's needed to unlock these

| Mechanic | Status | Strategy |
|----------|--------|----------|
| `caster_missing_hp` alias | **Done** (seeded) | Rage Engine |
| `caster_below_half` alias | Novel, trivial to add | Rage Engine |
| Survive-at-1 trigger in `check_target_death` | Novel, shared with Necromancer's Undying Will | Rage Engine |
| `number_of_adjacent_enemies` formula | Novel alias, shared infra with Monk | Ground Shaker |
| Knockback effect (push target 1 tile) | Novel positional effect type | Ground Shaker |
| `tiles_moved` alias | Novel, shared with Ranger + Monk | Juggernaut |
| `momentum` stacking status | Novel, same pattern as `soul_shards` | Juggernaut |
| Consume-all-of-type on status effects | Novel operation for Breaking Point / Shatterpoint | Juggernaut, Skullcrusher |
| Stance status effects (mutually exclusive) | Novel — remove opposite stance on apply | Weapon Master |
| `caster_in_axe_stance` / `caster_in_shield_stance` aliases | Novel aliases, trivial (`some` over status_effects) | Weapon Master |
| `armor_broken` stacking debuff | Novel — modifies shield application + `apply_damage` | Skullcrusher |
| `target_armor_broken_stacks` alias | Novel alias, trivial | Skullcrusher |
