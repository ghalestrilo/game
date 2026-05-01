# Paladin Deck Strategies

A design brainstorm for paladin archetypes — what each strategy wants to do, what cards it needs, and what mechanics (existing or new) make it tick.

---

## Existing mechanics the paladin can already exploit

| Mechanic | Card | Notes |
|----------|------|-------|
| Damage + heal | Holy Strike | 4 damage + 2 heal — the paladin's identity card |
| High shield | Righteous Defense | 8 shield + taunt — the tankiest single card in the game |
| AoE damage + heal | Consecration | 5 AoE damage + 3 AoE heal — a rare hybrid |
| Taunt | Righteous Defense | Forces enemy targeting — already seeded but unimplemented |
| Shield | Block, Divine Shield (cross-class) | Stacking mitigation |
| Cleanse | Purify (cross-class) | Remove debuffs |

---

## Strategy 1: Aura Paladin (Persistent passive buffs)

**Concept:** The paladin projects auras — passive area effects that continuously buff adjacent allies each turn. Unlike one-shot buffs, auras are permanent status effects that fire at turn start for every ally in range. The paladin doesn't play many cards per turn — they stack auras early and let the passive engine run.

**Wants:**
- Aura status effects on the paladin that buff adjacent allies each turn
- Cards that apply or upgrade auras
- Positioning synergy — staying adjacent to as many allies as possible
- A way to stack multiple distinct auras simultaneously

**Key novel card ideas:**
- **Devotion Aura** (1 AP) — Apply `aura_devotion` to self: at the start of each turn, adjacent allies gain `shield: 2`. Persistent — stays until dispelled.
- **Retribution Aura** (2 AP) — Apply `aura_retribution` to self: at the start of each turn, adjacent allies deal +2 damage on their next attack.
- **Crusader Aura** (1 AP) — Apply `aura_crusader` to self: adjacent allies move +1 tile per movement action.
- **Sanctified Ground** (2 AP) — Drop a persistent aura on the current tile rather than the paladin's person: adjacent allies on this tile heal 3 HP at turn start.
- **Aura Surge** (3 AP) — All currently active auras on the paladin fire immediately (deal their per-turn effect right now) in addition to firing at normal turn start.

**New mechanic needed:** Aura status effects that fire at the start of *other* characters' turns (not just the paladin's). This requires the `setup_player_turn` hook to iterate over all characters on the board and check for aura-bearing allies nearby, then apply effects. Auras are permanent (no value decrement) — a new `persistent: true` flag on the status effect struct, excluded from the `tick_status_effects` countdown.

---

## Strategy 2: Judicator (Punish evil, reward virtue)

**Concept:** The paladin deals bonus damage against enemies who have recently hurt allies, and bonus heals to allies who have recently taken damage. Every attack and every heal is conditional — did the target commit a sin (dealt damage) or suffer unjustly (took damage)? The paladin judges the board state and responds accordingly.

**Wants:**
- A `judged` marker applied when an enemy deals damage to an ally
- Cards that deal massively more damage to `judged` targets
- Cards that heal more if the target was recently damaged
- A passive that auto-marks aggressors without spending AP

**Key novel card ideas:**
- **Mark of Justice** (0 AP) — Passive: whenever any ally takes damage, apply `judged: 2` to the attacker automatically. No hand card — a triggered status applied via a post-damage hook.
- **Divine Retribution** (2 AP) — Deal `4 + (6 × judged_stacks)` damage to target. Consumes all `judged` stacks. The payoff — wait for the mark, then strike.
- **Absolution** (1 AP) — Heal target for `3 + (2 × damage_taken_this_turn)`. Rewards healing allies immediately after they're hit.
- **Condemn** (2 AP) — Apply `condemned: 3` to target: they take +50% damage from all sources for 3 turns. The paladin designates one enemy as the primary threat.
- **Judgment Day** (3 AP) — All enemies with `judged` stacks take damage equal to their stacks × 5 simultaneously. A board-wide execution of all marked aggressors.

**New mechanic needed:** `judged` auto-applied via the post-damage hook (same hook used by Cleric Holy Ward and Necromancer leech). `damage_taken_this_turn` counter on each character, incremented when `apply_damage` fires, reset at turn start. `condemned` multiplicative damage modifier in `apply_damage` pipeline — multiplies incoming damage by 1.5 (rounds up).

---

## Strategy 3: Crusader (Aggressive tank)

**Concept:** The most offensive paladin archetype — charge into enemies, taunt them all, and hit back harder than they expected. Taunt isn't a defensive tool here; it's a way to concentrate all enemy fire onto the paladin while they retaliate with massive Consecration-style AoE. Take every hit, make every hit count.

**Wants:**
- Taunt (already in Righteous Defense) as the core mechanic — fully implemented
- Cards that deal more damage when the paladin is being targeted
- Counterattack effects (deal damage on taking a hit)
- AoE damage that scales with how many enemies are adjacent

**Key novel card ideas:**
- **Challenge** (1 AP) — Apply `taunt: 3` to self. All enemies must target the paladin for 3 turns. Force all fire onto the paladin.
- **Holy Retribution** (1 AP) — Passive buff: for 2 turns, whenever the paladin takes damage, deal `damage_received ÷ 2` back to the attacker. A flat counterattack.
- **Blessed Fury** (2 AP) — Deal `4 × number_of_adjacent_enemies` holy damage to all adjacent enemies. The more they swarm, the harder this hits.
- **Bulwark of Faith** (2 AP) — Apply `shield: 10`. If the paladin currently has `taunt` active, apply `shield: 15` instead. Rewards leaning into the taunt fantasy.
- **Hammer of Wrath** (3 AP) — Deal 15 damage to target. Can only be played if the paladin has taken damage this turn. The reactive payoff — hurt me first, then face the hammer.

**Formula hook:** `number_of_adjacent_enemies` alias (shared with Barbarian Ground Shaker). `taunt_is_active` as a `caster_in_taunt` alias checking `some` over `status_effects`. `damage_taken_this_turn` counter shared with Judicator.

---

## Strategy 4: Oath Keeper (Vow system)

**Concept:** The paladin takes oaths at the start of the game (via cards played in the first two turns). Each oath is a permanent rule the paladin must follow — but following it grants a passive bonus. Breaking an oath (e.g., healing an enemy by mistake, attacking an ally) removes the bonus and applies a penalty. The deck is built around upholding specific oaths.

**Wants:**
- Oath cards played as setup (ideally turn 1)
- Permanent passive bonuses for each active oath
- Mechanics that can accidentally break oaths (AoE hit to allies, healing overshoot)
- An "Absolved" recovery card to restore a broken oath at cost

**Key novel card ideas:**
- **Oath of Devotion** (1 AP) — Permanent: the paladin gains `shield: 2` at the start of every turn. Oath condition: never deal damage to an ally.
- **Oath of Vengeance** (1 AP) — Permanent: all damage cards deal +3. Oath condition: never heal an enemy (tricky with AoE heals).
- **Oath of the Ancients** (2 AP) — Permanent: regen 2 at start of every turn. Oath condition: never move more than 2 tiles from the nearest ally.
- **Sacred Vow** (2 AP) — Apply any two oaths simultaneously. High value but doubles the constraint burden.
- **Holy Atonement** (2 AP) — Restore one broken oath. The paladin atones — reset the oath to active and pay a penance (lose 5 HP). Safety valve for when an oath breaks.

**New mechanic needed:** Oath cards apply permanent status effects with no duration. Oath-breaking conditions need hooks throughout the action pipeline: AoE damage checks if any ally was in the AoE radius, healing checks if the target was an enemy, movement checks tile distance after each move. These are event hooks on actions, not damage pipeline hooks — broader but thematically compelling.

---

## Strategy 5: Beacon of Light (Zone anchor)

**Concept:** The paladin plants themselves in one spot and becomes a beacon — a tile that radiates buffs to all allies within range each turn. They never move, and cards that reward standing still get dramatically stronger the longer the paladin holds position. Movement is the cost; being immovable is the identity.

**Wants:**
- Cards that check whether the paladin moved this turn (opposite of `tiles_moved` check — punish movement)
- Cards that get stronger each turn the paladin stays in the same position (a `stationary_turns` counter)
- High-range AoE heal and buff effects to support allies from a fixed point
- Immunity to forced movement (knockback, Lure)

**Key novel card ideas:**
- **Anchor** (0 AP) — Apply `anchored: 10` to self: immune to forced movement for 10 turns. Also: movement cards cannot be played while anchored. The commitment card.
- **Holy Beacon** (2 AP) — All allies within range 3 heal `3 + stationary_turns` HP. Scales with how long the paladin has been standing still.
- **Hallowed Ground** (2 AP) — Target the paladin's current tile. Apply a permanent aura: all allies who start their turn within 2 tiles gain `shield: 3`. Anchor + Hallowed Ground creates a fortified position.
- **Radiant Wave** (3 AP) — Deal `2 × stationary_turns` damage to all enemies within range 3. The offensive payoff for holding position — the longer the wait, the bigger the wave.
- **Immovable Object** (1 AP) — Buff: for 2 turns, any card that would move the paladin (including their own) is negated. Triggers a counterattack of 5 damage to whoever tried to move them.

**New mechanic needed:** `stationary_turns` counter — incremented at turn start if `current_turn.starting_position === current_turn.player.position` at the end of the previous turn (compare in `setup_player_turn`). `anchored` status blocks movement action validation. `tiles_not_moved_check` formula alias: `%{"===" => [%{"var" => "caster.position"}, %{"var" => "state.current_turn.starting_position"}]}`.

---

## Mechanic summary: what's needed to unlock these

| Mechanic | Status | Strategy |
|----------|--------|----------|
| Taunt (force enemy targeting) | Seeded, unimplemented — needs targeting validation hook | Crusader, Aura Paladin |
| Persistent status effects (`persistent: true`) | Novel — excluded from `tick_status_effects` countdown | Aura Paladin |
| Aura per-turn hook for adjacent allies | Novel — `setup_player_turn` scans for aura bearers nearby | Aura Paladin |
| Post-damage hook (auto-apply `judged`) | Novel, shared with Cleric Holy Ward, Necromancer leech | Judicator |
| `damage_taken_this_turn` counter | Novel — incremented in `apply_damage`, reset at turn start | Judicator, Crusader |
| `condemned` multiplicative damage modifier | Novel — multiplier in `apply_damage` pipeline | Judicator |
| `number_of_adjacent_enemies` formula | Novel alias, shared with Barbarian Ground Shaker | Crusader |
| `taunt_is_active` alias | Novel, trivial (`some` over status_effects) | Crusader |
| Oath permanent status effects | Novel — persistent, no duration tick | Oath Keeper |
| Oath-breaking event hooks across action pipeline | Novel — broad hooks on move, damage, heal actions | Oath Keeper |
| `stationary_turns` counter | Novel — compare position at turn start/end | Beacon of Light |
| `anchored` status (block movement) | Novel — checked in `process_action({:move, ...})` | Beacon of Light |
| Tile aura (shared infrastructure) | Novel, shared with Druid + Cleric | Beacon of Light |
