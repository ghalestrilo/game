# Mage Deck Strategies — Volume 2

Additional archetypes sharpening the mage's identity around perfect information, deck manipulation, and the grimoire fantasy. These strategies lean harder into the "calculated and controlled" thesis — the mage always knows what's coming.

---

## Strategy 6: Grimoire Mage (Scrying and deck tutoring)

**Concept:** The mage treats their deck as a library to be studied, not a random pile to be drawn from. Cards let them look at the top N cards, rearrange them, pull a specific spell directly into hand, or "bookmark" a card to draw it next turn. The mage is never surprised by their own draws — every card they play was planned two turns ago.

**Wants:**
- Scry effects: look at the top N cards of the draw pile without drawing them
- Tutor effects: search the draw pile for a specific named card and put it in hand
- Bookmark effects: set a card aside and draw it at the start of the next turn
- Cards that reward knowing the top of the deck (bonus if the next draw is a specific type)

**Key novel card ideas:**
- **Scry** (1 AP) — Look at the top 3 cards of your draw pile. Put them back in any order. No cards enter hand — pure information and reordering. The fundamental grimoire spell.
- **Foresight** (1 AP) — Look at the top 5 cards. Put up to 2 on the bottom, keep the rest on top in any order. More disruptive than Scry — actively buries unwanted cards.
- **Arcane Search** (2 AP) — Search your entire draw pile for one card by name. Put it in your hand. Shuffle the draw pile. The tutor — guarantees a specific card is available this turn.
- **Bookmark** (0 AP) — Choose a card in hand. Set it aside face-down. At the start of your next turn, draw it before your normal draw. Guarantees a card survives into the next turn even though hands are discarded at turn end.
- **Prescience** (1 AP) — Buff: if the next card you draw this turn was the top card of your draw pile before this turn started (i.e. you knew it was coming from Scry), it costs 0 AP. Rewards using Scry as a setup.
- **Grand Grimoire** (3 AP) — Look at your entire draw pile. Rearrange it in any order. Draw 2 cards. The mage's ultimate preparation card — the next several turns are fully scripted.

**New mechanic needed:** Scry UI — the player needs to see the top N cards of their draw pile and drag them to reorder. This is a UI concern more than a backend concern: the draw pile is already tracked on `character.cards.draw` as an ordered list. A `scry` effect type that returns the top N cards as visible state and accepts a reordered list back. `Bookmark` needs a `bookmarked_card` slot in the character state (or a `hand_preserved` status) that `draw_cards_for_player` checks before drawing normally. Tutoring requires searching `cards.draw` by card name and splicing — straightforward list operations.

---

## Strategy 7: Transmutation (Transform cards into other cards)

**Concept:** The mage transmutes cards — turning weak cards in hand into stronger ones, or converting one resource type into another. A hand full of Strike cards becomes a hand full of Fireballs. Cheap filler becomes premium spells. The mage starts every game with a mediocre deck and alchemically upgrades it mid-combat.

**Wants:**
- Cards that replace a card in hand with a different (usually better) card
- Cards that permanently upgrade a card in the draw pile (write a modified version back)
- A discard-and-replace engine that culls weak cards and inserts strong ones
- A capstone that transforms the entire hand simultaneously

**Key novel card ideas:**
- **Transmute** (1 AP) — Discard a card from hand. Draw a card of the same AP cost or higher from a special "transmuted" pool (a curated subset of powerful cards). Weak cards become power cards.
- **Alchemy** (2 AP) — Target a specific card in your draw pile by name. Replace it with a different card of your choice. Permanently upgrades the deck mid-game.
- **Philosopher's Stone** (0 AP) — Discard your entire hand. Draw that many cards +1. The aggressive cull — sacrifice a bad hand for a better one, with a card advantage bonus.
- **Refine** (1 AP) — Look at the top 2 cards of your draw pile. Discard one, keep one on top. Combines light scrying with culling.
- **Grand Transmutation** (3 AP) — Replace all cards currently in your draw pile with upgraded versions (each card becomes the next tier of rarity). A permanent deck power spike — common cards become uncommon, uncommon become rare.

**New mechanic needed:** A "transmuted pool" — a secondary card list that transmutation effects draw from, separate from the main draw pile. `Alchemy`'s targeted replacement needs a card-search-and-replace operation on `cards.draw`. `Grand Transmutation` requires a rarity upgrade map (common → uncommon → rare → legendary) and the ability to replace card structs in the draw pile at resolution time. `Philosopher's Stone` is mechanically straightforward — discard hand then draw — but the +1 bonus requires tracking how many were discarded.

---

## Strategy 8: Discard Mage (Discard for power)

**Concept:** Discarding is not a cost — it's a resource. Every card discarded from the mage's hand generates a `channeled` stack, and channeled stacks fuel devastating effects. The mage runs more cards than AP can play per turn intentionally, discarding the overflow to charge up. At peak efficiency, the mage discards 3 cards and plays one spell that hits for 30.

**Wants:**
- Cheap or free ways to voluntarily discard cards from hand
- Cards that deal damage or generate effects proportional to `channeled` stacks
- Cards that reward having a large hand (more to discard = more power)
- A way to draw aggressively to keep the discard engine fed

**Key novel card ideas:**
- **Channel** (0 AP) — Discard a card from hand. Gain 1 `channeled` stack. The fundamental engine card — zero cost, pure conversion.
- **Focused Discharge** (2 AP) — Spend all `channeled` stacks. Deal `5 × stacks_spent` damage to target. The finisher — 3 discards + this card = 15 damage for 2 AP.
- **Arcane Overflow** (1 AP) — Discard up to 3 cards. Gain 1 `channeled` stack per card discarded. Deal 2 damage per stack to all enemies. Combines channeling and AoE payoff in one card.
- **Overfull** (0 AP) — Can only be played with 5 cards in hand. Draw 2 cards. The hand-flooding card — only works when you're already holding maximum cards, which is exactly when you want more to discard.
- **Mana Void** (2 AP) — Discard your entire hand. Deal 4 damage to all enemies per card discarded. A hand of 5 cards = 20 AoE damage. High risk (you lose your whole hand), high reward.

**New mechanic needed:** `channeled` stacking status — same pattern as `ki`, `momentum`, `soul_shards`. Voluntary discard effect (`Channel`) — distinct from the existing Discard effect which targets enemies. A "discard from own hand" effect type that removes a chosen card from `caster.cards.hand` and increments `channeled`. `Overfull`'s hand-size gate is a targeting rule: `length(caster.cards.hand) >= 5`. `Mana Void` discard count needs to be captured before the discard fires to calculate the damage.

---

## Strategy 9: Time Mage (Temporal manipulation)

**Concept:** The mage manipulates the turn order itself — delaying enemies, taking extra turns, rewinding their own mistakes. Cards interact with the queue directly: push an enemy to the back, pull yourself to the front, replay your last turn. Time is the mage's element and the turn queue is their battlefield.

**Wants:**
- Cards that modify position in the turn queue
- A card that lets the mage take an additional full turn (expensive)
- A card that rewinds the mage's last action (undo)
- Cards that delay a specific enemy (push them later in the queue)

**Key novel card ideas:**
- **Haste** (2 AP) — Move the mage to the front of the turn queue. They act again immediately after the current turn ends, before any other character. A full extra turn.
- **Slow** (1 AP) — Move target enemy to the back of the turn queue. They act last this full rotation. Buys an entire rotation of safety.
- **Time Stop** (3 AP) — The mage takes 2 full turns in a row before the queue advances. The ultimate time manipulation — two complete turns of unopposed action.
- **Rewind** (2 AP) — Undo the mage's last card play: restore the AP spent, return the card to hand, and reverse the effect on the target. The safety net — expensive but recovers from a misplay or wasted turn.
- **Foreseen End** (1 AP) — Look at the next 2 cards any target character will draw. Does nothing else — pure information about an enemy's upcoming hand.

**New mechanic needed:** Queue manipulation — `rotate_queue` currently appends to the back and pops from the front. A `move_to_back` effect changes an enemy's position in `combat.queue` (find by ID, move to last). `Haste` inserts the mage at position 0 of the queue *after* the current turn ends. `Rewind` is the most complex — it requires storing the pre-card-play state snapshot and restoring it, essentially a one-step undo on `CombatState`. `Foreseen End` peeks at `target.cards.draw` — already accessible in the formula context, just needs a card that surfaces it as visible information to the player.

---

## Mechanic summary: what's needed to unlock these

| Mechanic | Status | Strategy |
|----------|--------|----------|
| `scry` effect type (view + reorder draw pile) | Novel — draw pile already ordered in `cards.draw` | Grimoire Mage |
| `bookmark` slot (preserve card across turns) | Novel — checked in `draw_cards_for_player` before normal draw | Grimoire Mage |
| Tutor effect (search draw pile by name) | Novel — list search + splice on `cards.draw` | Grimoire Mage |
| Transmuted card pool | Novel — secondary curated card list | Transmutation |
| Card replacement in draw pile (`Alchemy`) | Novel — search + replace in `cards.draw` | Transmutation |
| Rarity upgrade map (`Grand Transmutation`) | Novel — requires rarity ordering + card substitution table | Transmutation |
| `channeled` stacking status | Novel, same pattern as `ki` / `momentum` / `soul_shards` | Discard Mage |
| Voluntary self-discard effect | Novel — discard from `caster.cards.hand`, distinct from enemy Discard | Discard Mage |
| Hand-size gate in targeting rule | Novel formula: `length(caster.cards.hand) >= 5` | Discard Mage |
| Queue position manipulation | Novel — move character within `combat.queue` list | Time Mage |
| `Haste` insert-at-front | Novel — post-turn queue injection | Time Mage |
| `Rewind` state snapshot + restore | Novel — most complex single-card mechanic in all docs | Time Mage |
| `Foreseen End` — view enemy draw pile | Readable already (`target.cards.draw` in context) — UI only | Time Mage |
