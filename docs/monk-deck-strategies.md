# Monk Deck Strategies

A design brainstorm for monk archetypes — what each strategy wants to do, what cards it needs, and what mechanics (existing or new) make it tick.

---

## Existing mechanics the monk can already exploit

| Mechanic | Card | Notes |
|----------|------|-------|
| Low-cost damage | Strike, Backstab (cross-class) | Cheap cards = more actions per turn |
| Multi-strike | Multishot pattern | Multiple hits from one card, natural fit for a martial artist |
| Shield | Block, Defend | Temporary mitigation between bursts |
| Heal | Holy Strike (cross-class) | Small self-sustain on hit |
| Movement | Evade | Reposition freely |
| Execute scaling | Execute | Bonus on wounded enemies |

---

## Strategy 1: Combo Builder (Ki accumulation)

**Concept:** Each card played this turn adds 1 Ki charge. Cards played later in the same turn deal bonus damage or trigger bonus effects based on current Ki. The monk rewards playing many cheap cards in sequence — a turn with 3 cards feels exponentially stronger than a turn with 1.

**Wants:**
- A `ki` counter tracked per turn (resets at turn end)
- Cheap cards to build Ki quickly
- A finisher that spends or scales off accumulated Ki
- Draw cards to ensure enough hand size for long combo turns

**Key novel card ideas:**
- **Jab** (1 AP) — Deals 3 damage. Grants 1 Ki. The basic combo starter, played 2–3 times before the finisher.
- **Palm Strike** (1 AP) — Deals 3 damage + 1 per Ki spent. Consumes all Ki. The combo finisher — after 3 Jabs it hits for 6 total.
- **Flowing Form** (0 AP) — Draw 1 card. Grants 1 Ki. The combo extender that costs nothing but an action.
- **Dragon's Breath** (2 AP) — AoE damage equal to current Ki × 3. Expensive setup but rewards a full combo turn against grouped enemies.

**New mechanic needed:** A `ki` counter on the character (or current turn state) that increments on card play and resets each turn. Could live in `current_turn` as an extra field, or as a status effect with value = current Ki stacks. The formula context already exposes `current_turn`, so `state.current_turn.ki` would be directly accessible.

---

## Strategy 2: Iron Body (Absorb and punish)

**Concept:** Stack massive shield values, then play cards that deal damage proportional to how much shield the monk currently has. Absorbing hits is the damage engine, not a defensive fallback. The more you get hit, the harder you hit back.

**Wants:**
- High shield generation (Block, Defend, Divine Shield cross-class)
- Cards that convert shield stacks into damage
- A way to keep shields between turns (currently shields don't persist — this is the key novel twist)
- Cards that reward being targeted

**Key novel card ideas:**
- **Iron Skin** (1 AP) — Apply `shield: 4`. Unlike normal shields, tagged as `iron_skin` — persists into the next turn instead of expiring.
- **Shield Slam** (2 AP) — Deal damage equal to current shield value. Spends the shield entirely. Formula: `%{"var" => "caster.status_effects.shield.value"}`.
- **Endure** (1 AP) — For this turn, the next hit absorbed by shield grants 1 AP back. Makes tanking attacks profitable.
- **Counter Stance** (2 AP) — Buff: the next time the monk takes damage this turn, reflect 50% back to the attacker (rounded down). Needs a reactive status effect, same system as Riposte from the rogue doc.

**Formula hook:** Shield value is already stored as `%{type: :shield, value: N}` in `status_effects`. A `caster_shield_value` alias could extract it for Shield Slam.

---

## Strategy 3: Wind Dancer (Evasion + pressure)

**Concept:** Move every single turn, stay adjacent to different enemies, and play cards that get stronger the more the monk moved this turn. Never stand still — the whole deck is built around constant motion generating value.

**Wants:**
- Free or cheap movement (Evade is the template)
- Cards that scale off `tiles_moved` this turn (same formula alias proposed in the ranger doc)
- Cards that reward being adjacent to multiple enemies
- Cards that apply debuffs on movement (leaving a trail of effects)

**Key novel card ideas:**
- **Rushing Strike** (1 AP) — Move 1 tile toward target and deal damage equal to tiles moved this turn (minimum 2). Combines movement with damage, keeps the counter climbing.
- **Whirlwind Kick** (2 AP) — AoE damage to all adjacent enemies equal to `tiles_moved ÷ 2`. The dancing payoff card — weave through the enemy formation then explode.
- **Afterimage** (1 AP) — Leave a decoy on your previous position. The first enemy that attacks the decoy wastes their action. Needs a new inert tile token (simpler than traps — no trigger damage, just a dummy target).
- **Gale Step** (0 AP) — Move 1 tile. Draw 1 card if you've moved 3+ tiles this turn. Zero cost movement that rewards commitment to the mobile playstyle.

**Formula hook:** `tiles_moved` alias computes cube distance between `caster.starting_position` and `caster.position` — same alias proposed for the ranger Longshot card. Shared infrastructure, different flavors.

---

## Strategy 4: Pressure Point (Debuff stacker)

**Concept:** Each attack applies a stacking `weakened` or `vulnerable` debuff to the target. The more times the target has been struck, the more damage all subsequent hits deal. A slow grind that accelerates — the first hit does 3, the fifth hit does 12.

**Wants:**
- Cheap repeated attacks to stack the debuff quickly
- Cards that check or consume debuff stacks for bonus effects
- Multi-strike cards to apply multiple stacks from one play
- A way to prevent the target from cleansing debuffs (Purify counter)

**Key novel card ideas:**
- **Pressure Point** (1 AP) — Deal 2 damage, apply `vulnerable: 1`. The debuff stacks additively — each stack increases damage taken by 1.
- **Five-Point Strike** (2 AP) — Multi-strike: 5 hits of 1 damage each. Applies `vulnerable: 1` per hit. Fastest way to max out stacks.
- **Nerve Strike** (2 AP) — Apply `weakened: 2` (reduces target's AP by 1 next turn). Pairs with vulnerable for a dual-debuff lockdown.
- **Vital Blow** (3 AP) — Deal damage equal to `10 + (target.vulnerable_stacks × 4)`. The finisher that cashes out all accumulated stacks.

**New mechanic needed:** `vulnerable` as a stackable status where the value represents total damage bonus (not a duration). Damage calculation checks for `vulnerable` the same way it checks for `shield` in `Character.apply_damage/2` — but adds to incoming damage instead of reducing it.

---

## Strategy 5: Zen Healer (Support + sustain)

**Concept:** The monk acts as a durable frontline support — tanking hits, healing allies, and cycling cards to keep the team alive. Not a healer in the traditional sense: the monk deals damage to generate healing for others. Every offensive action sustains the team.

**Wants:**
- Cards that deal damage and heal an ally simultaneously (Holy Strike is the rough template)
- Cards that sacrifice HP to empower a teammate
- High sustain for the monk personally (regen, shields)
- Cards that reward having allies nearby

**Key novel card ideas:**
- **Mending Fist** (1 AP) — Deal 4 damage to an enemy. Heal the lowest-HP ally for the same amount. Single card that both pressures and sustains.
- **Sacrifice** (1 AP) — Lose 5 HP. An ally of your choice gains 8 HP. Deliberately inefficient for the monk but a net positive for the team.
- **Shared Pain** (2 AP) — Until your next turn, any damage the monk takes is split evenly with the attacker. Discourages focus fire.
- **Aura of Calm** (2 AP) — AOE heal for all allies equal to `3 + (number of allies adjacent to monk)`. Rewards tight formation play — the whole team clustering around the monk amplifies the heal.

**Formula hook:** `number_of_adjacent_allies` needs a formula that filters the queue by team and computes distance ≤ 1 from `caster.position`. The `filter` + `some` operators in JsonLogic can handle this once distance is available as a formula primitive.

---

## Mechanic summary: what's needed to unlock these

| Mechanic | Status | Strategy |
|----------|--------|----------|
| Multi-strike cards | **Done** (via `multi` field) | Combo Builder, Pressure Point |
| Shield (basic) | **Done** | Iron Body |
| `tiles_moved` formula alias | Novel alias, shared with Ranger Sniper | Wind Dancer, Combo Builder |
| Ki counter per turn | Novel — add to `current_turn` state or as a status effect | Combo Builder |
| Persistent shield (`iron_skin` tag) | Novel — shields currently don't persist across turns | Iron Body |
| Reactive/reflect status (Counter Stance) | Novel, same system as Rogue's Riposte | Iron Body |
| `caster_shield_value` formula alias | Novel alias, trivial to add | Iron Body |
| Trap/decoy tile tokens | Novel tile property (simpler variant of trapper traps) | Wind Dancer |
| `vulnerable` stackable debuff | Novel — additive damage amplifier on target | Pressure Point |
| Damage calculation hook for `vulnerable` | Modify `Character.apply_damage/2`, same location as shield logic | Pressure Point |
| `number_of_adjacent_allies` formula | Novel alias using `filter` + distance primitive | Zen Healer |
| Heal-on-damage-dealt effect | Novel — `mending_fist` effect type or composite effect | Zen Healer |
