# Necromancer Deck Strategies — Volume 2

Additional archetypes exploring curse cards, graveyard recursion, life-as-AP, and self-harm mechanics.

---

## Strategy 6: Curse Peddler (Poison the hand)

**Concept:** Slip curse cards into the opponent's hand or deck. Curse cards are unplayable traps — when drawn, they either fire immediately and hurt the opponent, or sit in hand consuming space until discarded. The necromancer wins by making the opponent's deck a liability rather than an asset.

**Wants:**
- Multiple curse card types with different punishment effects
- Ways to force the opponent to draw (accelerate the pain)
- Cards that check how many curses are in the opponent's hand
- Synergy with the Discard effect (force discards to cycle curses into hand faster)

**Key curse card types (these go into the opponent's hand/deck):**
- **Cursed Sigil** — When drawn, deal 5 damage to the holder. Auto-triggers on draw, cannot be played.
- **Withering Mark** — When played or discarded, apply `withered: 2` to self. Forces a bad choice: play it and suffer the debuff, or let it clog the hand.
- **Chain of Agony** — Costs 4 AP to play for 1 damage. Effectively unplayable — clogs the hand and taxes AP if the opponent panics and plays it.
- **Tainted Blessing** — When played, heal 3 HP but apply `hexed: 2` (heals become damage for 2 turns). Looks like a lifeline but is a trap.

**Necromancer cards that deliver curses:**
- **Cursed Gift** (1 AP) — Add 1 `Cursed Sigil` to target's hand. Cheap and immediate.
- **Nightmare** (2 AP) — Add 2 random curses from the curse pool to target's draw pile (shuffled in). Delayed pain.
- **Dread Pact** (2 AP) — Add a `Withering Mark` to each enemy's hand simultaneously. Scales with enemy count.
- **Forced Reading** (1 AP) — Force target to draw 2 cards immediately. Pairs with any curse already in their deck to accelerate the trigger.

**New mechanic needed:** Curse cards as a new card category that lives in a separate pool (not the necromancer's deck). `add_to_hand` and `add_to_deck` effect types — insert a specific card struct into a target character's hand or draw pile. Curse auto-trigger on draw requires a hook in `draw_cards` in `CombatState`. Cards that "cannot be played" need a new `unplayable: true` flag checked in `process_action({:pick_card, ...})`.

---

## Strategy 7: Graveyard Recursion (Cast from the dead)

**Concept:** The graveyard is a second hand. Cards that have been used aren't gone — they can be pulled back out and replayed, or their effects can be echoed from beyond. The necromancer turns the discard pile from a dead zone into an active resource.

**Wants:**
- Cards that target the necromancer's own discard pile
- Cards that replay the last effect used (echo)
- A way to convert the opponent's discard pile into threats (steal and recast)
- The graveyard as a growing pool that gets stronger as the game goes on

**Key novel card ideas:**
- **Exhume** (2 AP) — Return a random card from your discard pile to your hand. The baseline recursion engine.
- **Dark Echo** (1 AP) — Replay the last card effect that was used this game (by anyone). The necromancer turns the opponent's best play against them, or doubles their own previous effect.
- **Corpse Explosion** (2 AP) — Destroy a card in your discard pile. Deal damage equal to that card's AP cost × 4 to target. Discard a Snipe (3 AP) for 12 damage — rewards keeping high-cost cards in the graveyard rather than replaying them.
- **Stolen Soul** (2 AP) — Target an enemy. Move a random card from their discard pile into your hand. You can play it this turn as if it were your own.
- **Last Rites** (3 AP) — Replay every card in your discard pile simultaneously, each at value 1. A late-game explosion that fires off all the accumulated dead cards at once for a turn of chaos.

**New mechanic needed:** Tracking "last card played" on `CombatState` (a single extra field `current_turn.last_effect`). `Stolen Soul` needs cross-character discard pile targeting — currently `target.cards.discard` is read-only in formulas but not writable from an effect. `Last Rites` replaying all discard cards needs a new bulk-replay loop in card processing, with each effect resolved at a forced value of 1 to avoid runaway scaling.

---

## Strategy 8: Iron Maiden (Reflect & self-harm)

**Concept:** Apply the Iron Maiden curse to an enemy: every time they deal damage, they take a percentage of it themselves. Then bait them into attacking — either by being an appealing target or by summoning cheap undead as punching bags. The opponent's aggression becomes their own downfall.

**Wants:**
- Iron Maiden as the core curse (% reflect on outgoing damage)
- Cards that make the necromancer or their undead irresistible targets (taunt)
- Cards that amplify the reflect percentage
- A win condition that fires when the reflected damage kills the attacker

**Key novel card ideas:**
- **Iron Maiden** (2 AP) — Apply `iron_maiden: 30` to target (reflect 30% of outgoing damage to self, rounded up, for 2 turns). The flagship curse.
- **Spiked Coffin** (1 AP) — Apply `thorns: 2` to self or a friendly target: the next 2 hits against this unit reflect 4 flat damage to the attacker. A simpler flat-reflect variant, cheaper to set up.
- **Suffering** (1 AP) — Double the current `iron_maiden` value on a target (30% → 60%). One follow-up application makes Iron Maiden lethal.
- **Martyr** (1 AP) — Apply `taunt: 2` to a friendly undead. All enemies that can attack must target this unit. Funnels all incoming damage through the reflect.
- **Agonize** (2 AP) — Apply `iron_maiden: 20` to all enemies simultaneously. Low per-target percentage but hits the whole board — against a group they all start hurting themselves on every attack.

**New mechanic needed:** `iron_maiden` as a status that intercepts outgoing damage from the afflicted character — a pre-attack hook that fires `apply_damage(attacker, outgoing_damage × reflect_rate)` before the hit lands. This requires a new hook point in the damage pipeline: currently `Character.apply_damage` only handles the receiver. A `before_attack` status check on the attacker needs to be added to `process_card` for damage effects. `taunt` as a targeting constraint that overrides the attacker's targeting freedom.

---

## Strategy 9: Blood Mage (Life as AP)

**Concept:** HP and AP are the same resource. Every card can be paid for in HP instead of AP — at a steep but workable exchange rate. The necromancer never runs out of actions as long as they're alive, and plays cards far beyond what their AP pool normally allows. Pair with life drain to recoup what was spent.

**Wants:**
- A toggle or mode that enables HP-as-AP conversion
- Cards that are intentionally priced in HP rather than AP (the Death Ritual cards from Vol. 1 are the template, but this goes further — every card becomes eligible)
- Life drain synergy to offset the HP burn
- A threshold win condition: the necromancer wins if they survive a turn at 1 HP

**Key novel card ideas:**
- **Blood Price** (0 AP) — For this turn, all cards can be paid with HP at a rate of 3 HP per 1 AP. Activating this is itself free. The mode-enabler.
- **Vital Surge** (0 AP) — Pay 5 HP. Gain 2 AP immediately. A direct conversion without the mode — useful for a single burst turn without committing to full blood price.
- **Hemorrhage** (1 AP or 3 HP) — Deal 7 damage. Has both an AP cost and an HP cost printed on the card — the player chooses which to spend. The dual-cost card that makes the tradeoff explicit.
- **Crimson Pact** (2 AP) — For 3 turns, whenever the necromancer pays HP for a card, deal that same HP amount as damage to a target of your choice. Turns the self-harm into a weapon.
- **Exsanguinate** (already in Vol. 1) — Recontextualized here: in a Blood Mage deck, the necromancer deliberately spends HP on Blood Price to maximize missing HP, then fires Exsanguinate for a huge burst.

**New mechanic needed:** `Blood Price` needs a turn-level flag (`blood_price_active: true`) in `current_turn` state that the AP-spending logic in `process_card` checks before deducting AP — if active, deduct `cost × 3` HP instead. Dual-cost cards need a new optional `hp_cost` field alongside `ap` on the card schema. The choice of which to spend needs UI support (a confirmation step at card-play time, or a toggle the player sets in advance).

---

## Strategy 10: Lich Sovereign (Ascension & transformation)

**Concept:** The game has two phases for this deck. Phase 1: survive and accumulate Soul Shards by killing enemies (each kill banks a shard). Phase 2: spend all shards to Ascend — transforming the necromancer into a Lich with new cards, new base stats, and permanent passive effects. The transformation is a mid-game power spike that reshapes the entire board state.

**Wants:**
- A `soul_shards` counter that increments on kills
- Cards that spend shards for effects scaling with shard count
- The Ascend card as a hard win condition — once transformed, the Lich is dramatically more powerful
- Defensive early-game tools to survive until transformation

**Key novel card ideas:**
- **Soul Harvest** (0 AP, passive) — Whenever any character dies (enemy or ally), gain 1 Soul Shard. Not played from hand — a persistent passive on the necromancer. Tracked as a special `soul_shards` status with stacking value.
- **Shard Bolt** (1 AP) — Deal damage equal to current Soul Shards. Does not spend shards. A scaling damage card that rewards holding shards rather than spending them.
- **Consume Soul** (1 AP) — Spend 3 Soul Shards. Heal 8 HP. The sustain option for the patient accumulator.
- **Ascend** (3 AP) — Spend 10 Soul Shards. Replace the necromancer's current hand, deck, and status effects with the Lich loadout (a separate predefined deck). Set all stats to Lich base stats (new max HP, new max AP). The transformation event.
- **Lich's Edict** (Lich-only, 2 AP) — Available only after Ascension. Deal 10 damage to all enemies simultaneously. The Lich's signature board-clear, unavailable in Phase 1.

**New mechanic needed:** Soul Shards as a persistent counter — cleanest as a stacking status effect (`%{type: :soul_shards, value: N}`) since the status system already supports this pattern and the formula context already exposes `status_effects`. The kill hook needs a new callback in `check_target_death` — when `dead` flips to `true`, scan the queue for necromancer units and increment their shard count. `Ascend` is the most complex card in any of these docs: it swaps the character's entire card pool at runtime and modifies base stats, requiring `CombatState.replace_player/2` (already exists) with a freshly constructed Lich character struct that preserves position, team, and shard count.

---

## Mechanic summary: what's needed to unlock these

| Mechanic | Status | Strategy |
|----------|--------|----------|
| `add_to_hand` / `add_to_deck` effect types | Novel — insert card into target's hand or draw pile | Curse Peddler |
| Curse card category + auto-trigger on draw | Novel — hook in `draw_cards`, `unplayable` flag | Curse Peddler |
| `Forced Drawing` (force opponent to draw) | Novel effect type | Curse Peddler |
| `graveyard` list on CombatState | Novel (proposed in Vol. 1) | Graveyard Recursion |
| `last_effect` field on `current_turn` | Novel — track last played effect | Graveyard Recursion |
| Cross-character discard write (`Stolen Soul`) | Novel — writable discard target in effect pipeline | Graveyard Recursion |
| `iron_maiden` reflect status | Novel — pre-attack hook on the attacker in `process_card` | Iron Maiden |
| `thorns` flat reflect status | Novel — simpler variant of iron_maiden | Iron Maiden |
| `taunt` targeting constraint | Novel — overrides attacker's target selection | Iron Maiden |
| `blood_price_active` turn flag | Novel — add to `current_turn`, check in AP-spend logic | Blood Mage |
| `hp_cost` field on card schema | Novel — optional HP alternative cost, UI choice needed | Blood Mage |
| `soul_shards` stacking status | Novel — but fits existing status_effects pattern cleanly | Lich Sovereign |
| Kill hook in `check_target_death` | Novel — callback when `dead` flips to true | Lich Sovereign |
| `Ascend` runtime deck/stat swap | Novel — uses existing `replace_player/2`, complex orchestration | Lich Sovereign |
