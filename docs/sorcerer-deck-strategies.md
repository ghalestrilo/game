# Sorcerer Deck Strategies

A design brainstorm for sorcerer archetypes — what each strategy wants to do, what cards it needs, and what mechanics (existing or new) make it tick.

The sorcerer's distinction from the Mage: where the Mage is calculated and controlled (spell slots, resource management), the Sorcerer is wild and innate. Power surges unbidden. Cards can overload and backfire. The deck is unstable by design — higher ceiling, higher variance.

---

## Existing mechanics the sorcerer can already exploit

| Mechanic | Card | Notes |
|----------|------|-------|
| High-damage spells | Fireball, Lightning Bolt | Mage cross-class — pure damage shells |
| AoE | Arcane Explosion | Hits everything nearby |
| Stun | Lightning Bolt | Control component |
| Draw | Mana Shield pattern | Cycle to find key spells |
| Burn DoT | Moonfire (cross-class) | DoT foundation |

---

## Strategy 1: Wild Magic (Chaos and variance)

**Concept:** Every card the sorcerer plays has a chance to trigger a wild magic surge — a random secondary effect that fires in addition to the card's normal effect. Surges can be beneficial (extra damage, free draw, bonus heal) or chaotic (damage self, affect wrong target, teleport). The sorcerer leans into the chaos, running cards that increase surge chance and mitigate bad outcomes.

**Wants:**
- A `surge_charge` counter that builds each turn and increases surge probability
- Cards that deliberately trigger surges for powerful guaranteed effects
- Cards that re-roll or redirect a bad surge
- A high-ceiling surge table with memorable outcomes

**Key novel card ideas:**
- **Sorcerous Bolt** (1 AP) — Deal 5 damage. 30% chance to trigger a Wild Magic Surge. The core spell — cheap enough to spam, surge-prone enough to get interesting.
- **Surge Tap** (1 AP) — Increment `surge_charge` by 3. Draw 1 card. Deliberately overcharges the surge engine.
- **Controlled Chaos** (2 AP) — Trigger a Wild Magic Surge deliberately, but choose from 3 random outcomes instead of 1. The best of three bad-or-good things.
- **Tame the Surge** (1 AP) — Reset `surge_charge` to 0. Heal self for `surge_charge ÷ 2`. The safety valve — cash out the charge as healing before a blowback.

**Surge Table (examples):**
- Roll 1: Deal 8 bonus damage to the target
- Roll 2: Deal 4 damage to self
- Roll 3: Draw 2 cards
- Roll 4: Teleport the target 2 tiles in a random direction
- Roll 5: Apply `shield: 8` to self
- Roll 6: The card effect fires twice

**New mechanic needed:** Surge probability calculation in `process_card` — after effect resolution, roll against `surge_charge` + base odds. Surge table stored as a list of effect functions, one selected randomly. Randomness primitives (`rand` operator) need adding to the formula engine or handled as a special case in `process_card` outside the formula system.

---

## Strategy 2: Metamagic (Spell modification)

**Concept:** The sorcerer can modify spells before casting — extending their range, doubling their value, splitting them to hit two targets, or making them instant (cost 0 AP this turn). Metamagic uses a `sorcery_points` resource. Each modification costs points, and points regenerate slowly. The sorcerer spends most turns managing the point economy.

**Wants:**
- A `sorcery_points` resource (separate from AP)
- Cards that apply metamagic modifiers to the next spell played
- A suite of core spells that benefit from modification
- A way to regenerate sorcery points mid-combat

**Key novel card ideas:**
- **Empower** (0 AP, costs 2 sorcery points) — The next damage spell deals double damage.
- **Extend** (0 AP, costs 1 sorcery point) — The next status effect applied lasts 2 extra turns.
- **Twin** (0 AP, costs 3 sorcery points) — The next single-target spell fires twice, targeting two different enemies.
- **Quicken** (0 AP, costs 3 sorcery points) — The next spell costs 0 AP.
- **Font of Magic** (2 AP) — Restore 4 sorcery points. The regeneration card — necessary to sustain heavy metamagic use.

**New mechanic needed:** `sorcery_points` as a secondary resource on the character struct (alongside `ap`). Metamagic cards apply a pending modifier status (`empower_next`, `twin_next`) that `process_card` reads before resolving the next spell, then clears. `Twin` needs the effect to resolve twice with two targeting passes — a new two-target resolution loop.

---

## Strategy 3: Elemental Attunement (Elemental synergy chains)

**Concept:** The sorcerer attunes to one element per turn (fire, ice, lightning). Spells cast in attunement deal bonus damage of that type and apply a secondary elemental status. Hitting an already-afflicted target with a different element triggers a reaction — fire + ice = shatter (bonus damage), lightning + water = overload (stun + damage), etc.

**Wants:**
- Three attunement status effects (fire, ice, lightning)
- Elemental status effects applied by spells (burn, chill, shocked)
- Reaction triggers when two compatible elements combine on a target
- Cards that change attunement cheaply

**Key novel card ideas:**
- **Attune: Fire** (0 AP) — Apply `attuned_fire` to self. Remove other attunements. Fire spells deal +3 damage and apply `burning: 1`.
- **Attune: Ice** (0 AP) — Apply `attuned_ice`. Ice spells slow target and apply `chilled: 1`.
- **Attune: Lightning** (0 AP) — Apply `attuned_lightning`. Lightning spells apply `shocked: 1`.
- **Frost Spike** (1 AP) — Deal 4 damage. Apply `chilled: 1`. If target is already `burning`, trigger Melt reaction: deal 6 bonus damage and remove both statuses.
- **Overload** (2 AP) — Deal 6 damage. Apply `shocked: 1`. If target is already `chilled`, trigger Freeze reaction: root target for 2 turns.

**Formula hook:** Reaction checks look at `target.status_effects` for the compatible element using `some` — same pattern as `caster_is_hidden`. Reactions trigger inside the effect's `process/3` function. Attunement aliases follow the Barbarian stance / Druid form pattern.

---

## Strategy 4: Spell Surge (AP overinvestment)

**Concept:** Every spell can be overcharged — spend extra AP beyond its base cost to amplify the effect. A Fireball normally costs 2 AP for 8 damage; spend 4 AP for 12 damage; spend 6 AP for 16 damage. The sorcerer builds a deck around generating extra AP and spending it all on one catastrophic overcharged spell.

**Wants:**
- Spells with overcharge scaling (bonus effect per extra AP spent)
- Cards that generate bonus AP (cross-class or novel)
- A "mana burn" mechanic — spend more AP than available by borrowing from HP
- The overcharge cap as a design constraint (max 2× cost)

**Key novel card ideas:**
- **Overcharged Bolt** (2 AP base) — Deal 6 damage. For each additional AP spent (up to 4 extra), deal 3 more damage. Fully overcharged: 18 damage for 6 AP.
- **Arcane Surge** (1 AP) — Gain 2 AP immediately. Can only be played once per turn. The AP generator.
- **Mana Burn** (0 AP) — Gain `spell_power` equal to current AP spent this turn, then set AP to 0. Converts the entire AP pool into a spell-damage multiplier.
- **Ruinous Blast** (3 AP base) — Deal 10 damage AoE. Overcharge: spend up to 6 extra AP. Each extra AP adds 2 damage per target hit. Against 4 enemies and 6 extra AP: 10 + 12 = 22 per target.

**New mechanic needed:** Overcharge UI — when a player selects an overchargeable card, they choose how much extra AP to commit. This requires a new card-play step between `:pick_card` and `:play_card` where the overcharge amount is set. The extra AP is spent in `process_card` before effect resolution, and the effect value formula reads the extra AP as a context variable.

---

## Strategy 5: Bloodline Power (Draconic / Aberrant / Divine ancestry)

**Concept:** The sorcerer chooses a bloodline at the start of the game — one permanent card played in the first turn that reshapes the entire kit. Draconic bloodline adds a fire/ice/lightning bonus to every spell. Aberrant bloodline enables psychic effects (mind control, fear). Divine bloodline adds a heal to every damaging spell. The deck is built around one bloodline's identity.

**Wants:**
- A bloodline card played turn 1 that applies a permanent passive
- Cards that reference the active bloodline for conditional effects
- Each bloodline enabling a different secondary strategy
- Cross-bloodline cards that check which bloodline is active

**Key novel card ideas:**
- **Draconic Heritage** (1 AP, turn 1 only) — Apply permanent `bloodline_draconic`. All damage spells apply `burning: 1` to targets. Gain `shield: 3` at turn start each turn (scales are protective).
- **Aberrant Mark** (1 AP, turn 1 only) — Apply permanent `bloodline_aberrant`. All damage spells apply `feared: 1` (target moves away from caster next turn). Gain 1 AP when an enemy fails to attack due to fear.
- **Divine Spark** (1 AP, turn 1 only) — Apply permanent `bloodline_divine`. All damage spells heal the weakest ally for 3 HP after firing.
- **Ancestral Surge** (2 AP) — The effect depends on bloodline. Draconic: AoE fire nova (6 damage all nearby). Aberrant: Fear all enemies in range 2. Divine: Heal all allies for 6.
- **True Form** (3 AP) — Remove the bloodline status and re-apply it at double potency for 3 turns. Temporary ascension — the bloodline's effects double.

**New mechanic needed:** `turn_1_only` playability gate — a targeting rule that checks `state.turn_count == 1` (requires a `turn_count` field on `CombatState`, incremented in `rotate_queue`). `feared` status moves the character away from the fear source in `process_action({:move, ...})` automatically on their turn. `bloodline_divine`'s "heal weakest ally after damage" needs a post-damage hook that finds `min(queue, by: :hp)` on the caster's team and heals them.

---

## Mechanic summary: what's needed to unlock these

| Mechanic | Status | Strategy |
|----------|--------|----------|
| `surge_charge` stacking status | Novel, same pattern as `soul_shards` | Wild Magic |
| Surge probability + random outcome table | Novel — randomness in `process_card`, surge table as config | Wild Magic |
| `sorcery_points` secondary resource | Novel — new field on Character struct alongside `ap` | Metamagic |
| Pending modifier statuses (`empower_next` etc.) | Novel — read and cleared in `process_card` before spell | Metamagic |
| `Twin` dual-target resolution | Novel — two-target effect loop | Metamagic |
| Elemental attunement statuses | Novel, same mutually-exclusive pattern as stances/forms | Elemental Attunement |
| Elemental reaction triggers | Novel — inside `process/3`, check target status_effects | Elemental Attunement |
| Overcharge AP selection step | Novel — new step between `:pick_card` and `:play_card` | Spell Surge |
| Extra AP context variable in effect formulas | Novel — inject `extra_ap` into `build_effect_context` | Spell Surge |
| Bloodline permanent status effects | Novel — persistent, shared with Paladin Oath system | Bloodline Power |
| `turn_count` on CombatState | Novel — incremented in `rotate_queue` | Bloodline Power |
| `feared` status (auto-retreat movement) | Novel — triggers movement in `process_action` | Bloodline Power |
| Post-damage "heal weakest ally" hook | Novel — `min` over queue by HP in post-damage callback | Bloodline Power |
