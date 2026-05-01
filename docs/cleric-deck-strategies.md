# Cleric Deck Strategies

A design brainstorm for cleric archetypes — what each strategy wants to do, what cards it needs, and what mechanics (existing or new) make it tick.

---

## Existing mechanics the cleric can already exploit

| Mechanic | Card | Notes |
|----------|------|-------|
| Single-target heal | Heal | 5 HP for 1 AP — the baseline |
| AoE heal | Group Heal | 3 HP to all nearby allies for 3 AP |
| Cleanse | Purify | Remove debuffs + minor heal |
| Shield | Divine Shield | 7 shield + 1 heal — the cleric's tank tool |
| Damage + heal | Holy Strike (cross-class) | Hybrid offensive healing |

---

## Strategy 1: Lifeline (Reactive burst healing)

**Concept:** Do nothing until an ally drops critically low, then restore them to full in a single turn with a burst of cheap, high-value heals. The cleric watches, waits, and erupts. Reactive rather than proactive — cards held in hand are potential energy until the moment they're needed.

**Wants:**
- Cheap heals to chain multiple in one turn
- Cards that heal more when the target is low (`target_below_half`, `target_missing_hp`)
- A "save" card that guarantees a near-dead ally survives the next hit
- Draw cards to ensure a full hand is available when the crisis arrives

**Key novel card ideas:**
- **Triage** (1 AP) — Heal target for `4 + target_missing_hp ÷ 2`. Scales up as the target gets more hurt. Formula: `%{"+" => [4, %{"/" => [%{"alias" => "target_missing_hp"}, 2]}]}`.
- **Miracle** (2 AP) — Only playable on a target below 25% HP. Restore them to full HP. The emergency button — a full heal with a low-HP gate.
- **Last Rites** (1 AP) — Apply `death_ward: 1` to target: if they would die this turn, survive at 1 HP instead. One-time insurance, same mechanic as Necromancer's Undying Will.
- **Blessed Rush** (0 AP) — Heal target for 2. Can only be played as the 2nd or later card this turn. Free triage extender — useless as a first play but excellent chained after Triage.

**Formula hook:** `target_missing_hp` and `target_below_half` aliases already seeded. `Triage` is a direct formula drop-in. `Miracle` uses a targeting rule gate on `target.hp ≤ target.max_hp × 0.25`.

---

## Strategy 2: Shield Wall (Proactive damage prevention)

**Concept:** Never let allies take damage in the first place. Stack shields on the whole team preemptively so that by the time enemies act, every hit is absorbed. The cleric becomes a permanent buffer — more value from preventing 8 damage than healing it back.

**Wants:**
- High shield values distributed to allies (Divine Shield is the template)
- Cards that shield multiple allies simultaneously
- Cards that refresh shields at the start of enemy turns
- A way to make shields persistent (survive into the next turn, as proposed in the Monk Iron Body doc)

**Key novel card ideas:**
- **Bulwark** (2 AP) — Apply `shield: 5` to all allies simultaneously. The AoE shield — expensive but covers the whole team.
- **Aegis** (1 AP) — Apply `iron_shield: 4` to target (persistent — does not expire at turn end). The key distinction from normal shields. Requires the persistent shield tag from Monk Iron Body doc.
- **Blessed Barrier** (2 AP) — Apply `shield: 6` to target. If they already have a shield, add to its value instead of replacing it. Shield stacking — currently shields are replaced, not stacked.
- **Holy Ward** (2 AP) — Buff: for 2 turns, whenever any ally takes damage, they automatically gain `shield: 2` afterward. Reactive shielding — the team regenerates defense as they absorb hits.
- **Sanctuary** (3 AP) — Apply `sanctuary: 2` to target ally: they cannot be targeted by enemies for 2 turns. Untargetable — absolute immunity rather than damage reduction.

**New mechanic needed:** Persistent `iron_shield` variant (shared with Monk). Shield stacking (add to existing value rather than replace). `sanctuary` as an untargetable status — checked in the targeting rule validation step in `process_action({:play_card, ...})`. `Holy Ward` is a reactive buff that fires `add_status_effect(:shield, 2)` whenever damage is applied to any ally — needs a post-damage hook.

---

## Strategy 3: Holy Smite (Aggressive offensive cleric)

**Concept:** The cleric deals more damage than expected because every hit is divinely amplified. Cards scale off how much HP has been healed over the course of the game — each heal charges a `faith` counter, and faith is spent on devastating holy attacks. The cleric's support role directly fuels their offensive capability.

**Wants:**
- A `faith` counter that increments each time HP is healed (by any amount, any source)
- Cards that spend faith for bonus damage
- Cards that simultaneously heal and deal damage
- A faith threshold finisher (deal massive damage when faith is maxed)

**Key novel card ideas:**
- **Smite** (1 AP) — Deal 4 damage. Gain 1 faith per 3 HP healed so far this game (passive faith accumulation).
- **Divine Judgment** (2 AP) — Deal `3 + faith_stacks` damage. Spend 3 faith. The faith-consuming strike.
- **Holy Nova** (2 AP) — Deal 4 damage to all enemies and heal all allies for 4. Charges faith equal to the total HP healed. AoE on both axes — the cleric's hybrid signature.
- **Radiant Burst** (3 AP) — Spend all faith. Deal `5 × faith_spent` damage to target. The faith finisher — save 5–6 stacks for a single massive blow.
- **Consecrated Ground** (2 AP) — Target a tile. For 2 turns, any ally who starts their turn on that tile gains 2 faith and heals 3 HP. Persistent zone effect — places a buff aura on the grid.

**New mechanic needed:** `faith` as a stacking status on the cleric, incremented by a heal hook (post-`apply_healing` callback). `Consecrated Ground` is a zone aura on a tile — a new `aura` tile property that applies an effect at the start of each turn to any character standing on it. Simpler variant of the Ranger's trap tile system.

---

## Strategy 4: Undying Support (Death-defying team preservation)

**Concept:** Allies don't die. The cleric loads the team with so many resurrection effects, death wards, and last-stand buffs that killing a single target is nearly impossible. The cleric wins by exhaustion — the enemy runs out of attacks before the team runs out of lives.

**Wants:**
- Death ward effects (prevent the killing blow)
- True resurrection (bring back a dead ally)
- Buffs that grow stronger each time an ally survives a killing blow
- High cleanse density to remove execution-enabling debuffs

**Key novel card ideas:**
- **Resurrection** (3 AP) — Target a dead ally. Restore them at 50% HP. Requires the `graveyard` system (proposed in Necromancer Vol. 1). The cleric's signature high-cost miracle.
- **Guardian Angel** (2 AP) — Apply `death_ward: 1` to target ally. On death, they survive at 1 HP once. Same mechanic as `Last Rites` above, but as a standalone card.
- **Tenacity** (1 AP) — Target ally gains `tenacious: 1`. Each time they survive a killing blow (via death ward), they permanently gain `max_hp + 3`. Stacks — the more times saved, the harder they get to kill.
- **Mass Cleanse** (2 AP) — Remove all debuffs from all allies simultaneously. Counters the Necromancer's Curse Weaver and the Bard's Dissonance.
- **Second Wind** (1 AP) — Target ally immediately heals for half their missing HP. Not a full heal — a safety top-up to keep them above the death threshold.

**New mechanic needed:** `graveyard` system on `CombatState` (shared with Necromancer Horde). `death_ward` trigger in `check_target_death` — intercept the death check, flip `dead` back to false, set HP to 1. `tenacious` modifies `max_hp` on survival trigger — a permanent stat increase stored on the character struct.

---

## Strategy 5: Miracle Worker (Conditional power spikes)

**Concept:** Most cleric cards are mediocre at baseline but become dramatically powerful under specific conditions — if an ally is below half HP, if the cleric healed last turn, if more than 2 allies are alive. The cleric plays a constant game of reading board state and fishing for the perfect condition, then unleashing an outsized card.

**Wants:**
- Cards with strong conditional effects gated by board-state formulas
- Cards that check how many allies are alive
- Cards that check whether the cleric healed last turn (a `healed_this_turn` flag)
- A cycling engine to draw into conditions quickly

**Key novel card ideas:**
- **Blessed Strike** (1 AP) — Deal 3 damage. If any ally is below 50% HP, deal 9 instead. Formula: checks `some` over queue filtered by team for `hp < max_hp ÷ 2`.
- **Faith Restored** (1 AP) — Heal target for 3. If the cleric healed on their last turn, heal for 7 instead. Rewards consistency — keep healing every turn.
- **Divine Favor** (2 AP) — Apply `shield: 4` to all allies. If 3 or more allies are alive, apply `shield: 8` instead. Team-size-dependent scaling — more powerful in a full squad.
- **Greater Miracle** (2 AP) — Heal all allies for 5. Can only be played if at least one ally is at 1 HP. The board-reading payoff — wait for the worst moment, then save everyone.
- **Righteous Fury** (3 AP) — Deal `6 × number_of_alive_allies` damage to target. Scales with how much the cleric has preserved — keeping allies alive makes the finisher stronger.

**Formula hook:** `some` + `filter` over queue to check alive ally HP thresholds — same infrastructure as `number_of_adjacent_allies` from the Monk doc. `healed_this_turn` flag as a boolean status set by the heal effect, cleared at turn start in `setup_player_turn`. `number_of_alive_allies` alias filters queue by team and `dead == false`.

---

## Mechanic summary: what's needed to unlock these

| Mechanic | Status | Strategy |
|----------|--------|----------|
| `target_missing_hp` alias | **Done** (seeded) | Lifeline |
| `target_below_half` alias | **Done** (seeded) | Lifeline |
| `death_ward` trigger in `check_target_death` | Novel, shared with Necromancer Undying Will | Lifeline, Undying Support |
| Persistent `iron_shield` variant | Novel, shared with Monk Iron Body | Shield Wall |
| Shield stacking (add, not replace) | Novel — modify `add_status_effect` or `process` in Shield | Shield Wall |
| `sanctuary` untargetable status | Novel — checked in targeting rule validation | Shield Wall |
| Post-damage reactive shield hook | Novel — `Holy Ward` fires after any ally takes damage | Shield Wall |
| `faith` stacking status + heal hook | Novel — post-`apply_healing` callback increments faith | Holy Smite |
| `Consecrated Ground` tile aura | Novel tile property, simpler variant of trap system | Holy Smite |
| `graveyard` system on CombatState | Novel, shared with Necromancer Horde | Undying Support |
| `tenacious` permanent max_hp growth | Novel — persistent stat modifier on death_ward trigger | Undying Support |
| `healed_this_turn` flag | Novel boolean status, cleared in `setup_player_turn` | Miracle Worker |
| `number_of_alive_allies` formula alias | Novel, shared infra with Monk + Monk Zen Healer | Miracle Worker |
