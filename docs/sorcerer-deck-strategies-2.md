# Sorcerer Deck Strategies — Volume 2

Additional archetypes sharpening the sorcerer's identity around instinct, variance, and raw innate power. These strategies lean harder into the "unstable, high-ceiling" thesis — the sorcerer doesn't plan, they erupt.

---

## Strategy 6: Font of Power (Discard for AP)

**Concept:** The sorcerer's raw magic is so overwhelming that they can't contain it — cards burn out of their hand as pure fuel. Discarding is not losing a resource; it's *releasing* magic. Every card discarded this turn generates AP that can be spent on stronger spells immediately. The sorcerer plays aggressively, discards the overflow, and converts the entire hand into one catastrophic action.

**Wants:**
- AP generation from voluntary discards
- Expensive, high-impact spells to spend the generated AP on
- A hand-flooding engine to always have cards to discard
- Cards that reward having 0 cards in hand at the end of the discard chain

**Key novel card ideas:**
- **Burn Out** (0 AP) — Discard a card from hand. Gain 1 AP. The core engine — each discard fuels the next play.
- **Release** (0 AP) — Discard your entire hand. Gain 1 AP per card discarded. If you discarded 3+, also draw 2 cards. The all-in version — burn everything, get the AP spike, then partially restock.
- **Torrent** (variable AP) — Deals `3 × AP spent` damage. No fixed cost — you declare how many AP to pour into it when played. Pair with Release for a turn that ends with a 15-damage single nuke.
- **Overflow** (1 AP) — Draw 3 cards. Can only be played if you have 2 or fewer cards in hand. The refuel card — keeps the discard engine running by restoring the hand after burning it down.
- **Conflagration** (0 AP) — Discard a card. Deal damage equal to the discarded card's AP cost × 4 to all enemies. The discard-as-damage card — discard a 3-AP spell to deal 12 AoE damage without casting it. The card's latent power explodes outward.

**Design distinction from Discard Mage (Mage Vol. 2):** The Mage's Discard engine accumulates `channeled` stacks and spends them in a later burst — patient, calculated, two-phase. The Sorcerer's Font of Power converts discards into AP *immediately* and spends them *immediately* in the same turn — impulsive, all-in, single-phase. Different rhythms, different risk profiles.

**New mechanic needed:** AP-generating discard — a `discard_for_ap` effect type that removes a card from `caster.cards.hand` (chosen by player) and calls `spend_ap` in reverse (add AP to current player). `Conflagration` needs to read the discarded card's AP cost before discarding — capture the cost as a local value, then discard, then apply damage formula using the captured value. `Torrent`'s variable cost requires the overcharge AP selection step proposed in Sorcerer Vol. 1 (Spell Surge strategy) — shared infrastructure.

---

## Strategy 7: Innate Surge (Raw power, no setup)

**Concept:** Every card the sorcerer plays is the strongest version of itself with no prerequisites. No stacking buffs, no scrying, no resource accumulation — just spells that hit hard on turn 1 and keep hitting hard. The identity is purity: a deck with 10 cards that each do one devastating thing. The sorcerer wins before the opponent can set up their engine.

**Wants:**
- The highest raw damage-per-AP ratio in the game
- Cards with no conditions, no setup, no synergy requirements
- A small deck (fewer cards, see them more often)
- Discard cards specifically to *thin* the deck — remove weak cards to draw power cards faster

**Key novel card ideas:**
- **Raw Power** (2 AP) — Deal 12 damage. No conditions, no effects, no secondary triggers. Pure damage — the highest printed value for 2 AP in the game.
- **Instinct** (1 AP) — Deal 7 damage. No conditions. The cheap version — 7 for 1 AP is the best damage rate in the game at baseline.
- **Purge Weakness** (0 AP) — Permanently remove a chosen card from your deck. It is gone for the rest of the game. Deck-thinning as a strategy — cut Strike and Defend fillers, draw Instinct every turn instead.
- **Unfettered** (1 AP) — Remove all status effects (positive and negative) from self. Draw 1 card. The sorcerer refuses to be bound by anything — dispels their own debuffs *and* their own buffs. Pure state.
- **Apex Spell** (3 AP) — Deal 20 damage. The hardest-hitting card in the game. No conditions. The deck is built around drawing and playing this.

**Design distinction from Mage Arcane Scholar:** The Scholar manages spell slots carefully, hoarding them for the right moment. Innate Surge has no slots, no resource — just spells. The Scholar's power is rationed; the Sorcerer's power is inexhaustible but must be drawn. Deck thinning (Purge Weakness) is the mechanic that makes the Sorcerer's inexhaustibility actually feel that way.

**New mechanic needed:** Permanent card removal from deck — `Purge Weakness` removes a card from the character's deck *and* the base deck reference, so it doesn't come back when the discard pile is reshuffled. This requires distinguishing "permanent removal" from "discarded" in the card state, either with a `purged` list on the character or by truly splicing from all three piles simultaneously.

---

## Strategy 8: Storm Caller (Persistent elemental field)

**Concept:** The sorcerer doesn't cast individual spells — they reshape the entire battlefield's elemental state. A storm persists for multiple turns, dealing damage to everyone who stays in it. A frost field slows all movement. A lightning storm stuns anyone who casts a spell. The sorcerer places the field and repositions to the edge; enemies must choose between staying in the damage zone or spending turns escaping it.

**Wants:**
- Persistent AoE fields placed on regions of the grid (not single tiles, but radius zones)
- Fields that deal per-turn damage or apply status effects to all characters in them
- Cards that intensify or move existing fields
- Positioning tools to stay outside the storm's radius

**Key novel card ideas:**
- **Summon Storm** (2 AP) — Place a `lightning_storm` field centered on target tile, radius 2. Each turn, all characters in the field take 3 damage and have a 50% chance of being `stunned: 1`. Lasts 3 turns.
- **Frost Field** (2 AP) — Place a `frost_field`, radius 2. All characters in the field have movement range reduced by 1 and take 2 damage per turn. Lasts 3 turns.
- **Inferno** (3 AP) — Place a `fire_field`, radius 3. All characters in the field take 4 damage and gain `burning: 1` per turn. Lasts 2 turns. The most damaging field but shortest duration.
- **Intensify** (1 AP) — Double the damage of a field you control for 1 turn. No new field — amplifies an existing one.
- **Eye of the Storm** (1 AP) — Move a field you control up to 3 tiles in any direction. Herd enemies into your damage zone, or chase retreating ones.

**Design distinction from Druid Nature's Wrath:** The Druid places single-tile terrain modifiers as permanent map features to create choke points. The Sorcerer places multi-tile *temporary* damage fields as aggressive offensive tools that move and intensify. One is territorial control; the other is mobile bombardment.

**New mechanic needed:** Multi-tile field effect — a new data structure on `CombatState` (a `fields` list, each with `center`, `radius`, `effect`, `duration`). At the start of each turn in `setup_player_turn`, all fields are ticked: apply their effect to every character within radius, then decrement duration and remove expired fields. `Eye of the Storm` moves the `center` coordinate of an existing field. Fields overlap — being in two fields simultaneously takes damage from both. This is the most substantial new system proposed in this volume.

---

## Strategy 9: Wild Bloodline (Chaos as identity)

**Concept:** The sorcerer's bloodline is unstable — a mix of dragon, demon, and fey all at once, expressing randomly. Each turn, roll to determine which bloodline is dominant this turn. Dragon = fire bonus. Demon = leech. Fey = charm + blink access. The sorcerer can't control which comes up but builds a deck that benefits from all three. Good play means making every bloodline state useful.

**Wants:**
- A random bloodline state rolled each turn (not chosen, unlike Sorcerer Vol. 1's Bloodline Power)
- Cards that check current bloodline and branch effects accordingly
- Cards that are powerful in *any* bloodline state (generalist tools)
- A way to re-roll or lock in a preferred bloodline temporarily

**Key novel card ideas:**
- **Chaotic Heritage** (1 AP) — At the start of each turn, randomly apply one of `bloodline_dragon`, `bloodline_demon`, or `bloodline_fey`. The passive identity — replaces the fixed-bloodline concept entirely.
- **Primal Bolt** (1 AP) — Deal 4 damage. In `bloodline_dragon`: apply `burning: 1`. In `bloodline_demon`: heal self for 4. In `bloodline_fey`: apply `charmed: 1` to target. One card, three distinct outcomes.
- **Embrace Chaos** (1 AP) — Reroll the current bloodline. Draw 1 card. The re-roll button — use when the current bloodline doesn't fit the hand.
- **Stabilize** (1 AP) — Lock the current bloodline for 2 turns (no reroll at turn start). The commitment card — when you get the bloodline you want, hold it.
- **All or Nothing** (2 AP) — Trigger the effect of all three bloodlines simultaneously. All bloodline passives fire at once for this turn only. The chaotic peak — unpredictable but always powerful.

**Design distinction from Bloodline Power (Sorcerer Vol. 1):** Vol. 1 picks one bloodline and commits permanently — it's a character-building decision. Wild Bloodline rolls every turn — it's a variance management game. One is identity; the other is adaptation.

**New mechanic needed:** Random bloodline roll at turn start — in `setup_player_turn`, after `tick_status_effects`, apply a randomly selected bloodline status (replacing the previous one). Random selection needs a lightweight randomness primitive accessible during turn setup (`:rand.uniform(3)` in Elixir is trivial). `All or Nothing` fires all three bloodline passive effects simultaneously — needs the bloodline passive system from Vol. 1 to be modular enough to invoke individually.

---

## Mechanic summary: what's needed to unlock these

| Mechanic | Status | Strategy |
|----------|--------|----------|
| `discard_for_ap` effect type | Novel — reverse `spend_ap`, remove from `caster.cards.hand` | Font of Power |
| `Conflagration` discarded-card cost capture | Novel — read AP cost before discard, use in damage formula | Font of Power |
| Variable-cost card (`Torrent`) | Novel, shared with Sorcerer Vol. 1 Spell Surge overcharge step | Font of Power |
| Permanent card removal (`Purge Weakness`) | Novel — remove from all piles + a `purged` list to prevent reshuffle | Innate Surge |
| Multi-tile field system (`fields` list on CombatState) | Novel — center + radius + effect + duration, ticked in `setup_player_turn` | Storm Caller |
| Field movement (`Eye of the Storm`) | Novel — mutate `center` coordinate of an existing field | Storm Caller |
| Field overlap (multiple simultaneous fields) | Falls out naturally from the field system if implemented correctly | Storm Caller |
| Random bloodline roll at turn start | Novel — `:rand.uniform` in `setup_player_turn`, trivial in Elixir | Wild Bloodline |
| Modular bloodline passive invocation | Novel — bloodline effects need to be callable individually for `All or Nothing` | Wild Bloodline |
