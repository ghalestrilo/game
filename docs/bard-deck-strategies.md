# Bard Deck Strategies

A design brainstorm for bard archetypes — what each strategy wants to do, what cards it needs, and what mechanics (existing or new) make it tick.

---

## Existing mechanics the bard can already exploit

| Mechanic | Card | Notes |
|----------|------|-------|
| Draw | Mana Shield pattern | Card draw is the bard's natural resource engine |
| Heal | Heal, Holy Strike (cross-class) | Support role baseline |
| Discard | Discard effect | Strip enemy hand — flavored as distracting performances |
| Summon | Summon effect | Flavored as summoning a fan, a muse, or a conjured instrument |
| Shield | Defend, Block (cross-class) | Light mitigation between performances |
| AoE | Arcane Explosion (cross-class) | Flavored as sonic blast |

---

## Strategy 1: Inspiration Engine (Buff the whole team)

**Concept:** The bard never deals meaningful damage themselves. Instead, every card played buffs an ally — granting AP, boosting their next attack, healing them, or drawing cards for them. The bard multiplies the output of the whole team. In a team fight, a bard turn that empowers two allies is worth more than two offensive turns.

**Wants:**
- Cards that grant AP to an ally
- Cards that buff an ally's next card (damage amplifier)
- Cards that draw cards for an ally
- A passive that triggers when any ally plays a card (echoed inspiration)

**Key novel card ideas:**
- **Inspire** (1 AP) — Target an ally. They gain 1 AP immediately. The most direct buff — turns a 2 AP turn into a 3 AP turn for a teammate.
- **Battle Hymn** (2 AP) — All allies deal +3 damage on their next attack this turn (if it's their turn) or next turn. AoE buff, short duration.
- **Rallying Cry** (1 AP) — Target ally draws 2 cards. Hand advantage delivered directly to the character who needs it most.
- **Encore** (2 AP) — The last card effect any ally played this turn is replayed at half value, targeting the same target. Doubles the best play of the round.
- **Crescendo** (3 AP) — All allies immediately take one free basic action (draw 1 card and gain 1 AP). The bard's ultimate — a full-team acceleration turn.

**New mechanic needed:** `grant_ap` effect targeting an ally (proposed in Ranger Beastmaster doc — shared infrastructure). `Encore` needs `last_effect` tracking on `current_turn` (proposed in Necromancer Graveyard Recursion). `Battle Hymn` needs a `damage_bonus` buff status on each ally that the damage pipeline reads and consumes on next hit.

---

## Strategy 2: Dissonance (Crowd control through sound)

**Concept:** The bard weaponizes their performance to disorient, silence, and confuse enemies. Cards apply debuffs that disrupt the opponent's turn: silence (can't play cards), confusion (cards target randomly), or taunt (must target the bard). The bard survives through misdirection rather than defense.

**Wants:**
- Silence as a new status effect (can't play cards for N turns)
- Confusion as a new status effect (next card targets a random valid target)
- Cards that reposition enemies against their will
- A finale card that stacks all dissonance effects for a full lockdown turn

**Key novel card ideas:**
- **Dissonant Chord** (1 AP) — Apply `silenced: 1` to target (they cannot play cards on their next turn). The bard's most powerful single debuff.
- **Cacophony** (2 AP) — AoE: apply `confused: 1` to all enemies in range 2. On their next turn, each confused character's first card fires at a random valid target instead of their chosen one.
- **Taunt Song** (1 AP) — Apply `charmed: 2` to target enemy: they must target the bard with their next 2 attacks. Combines with evasion or ally positioning to waste enemy turns.
- **Shatter Performance** (2 AP) — Force target to discard their entire hand, then draw 2 random cards. Disrupts a carefully assembled hand mid-turn.
- **Grand Finale** (3 AP) — Apply `silenced: 1`, `confused: 1`, and `weakened: 2` to target simultaneously. The full lockdown — their next turn is nearly useless.

**New mechanic needed:** `silenced` status blocks card play — checked in `process_action({:pick_card, ...})`. `confused` redirects targeting — intercepts the target selection step in `process_card`, replacing the chosen target with a random valid one. `charmed` is a variant of `taunt` targeting a specific character instead of the taunt-holder.

---

## Strategy 3: Copycat (Mirror and steal)

**Concept:** The bard copies what others do. When an enemy plays a powerful card, the bard plays it back the following turn. When an ally achieves something great, the bard echoes it. The deck has few original damage cards — nearly everything is stolen, copied, or echoed from the surrounding combat.

**Wants:**
- Cards that copy the last effect played by any character
- Cards that steal a card from the enemy's hand and play it immediately
- A persistent echo effect that automatically mirrors one enemy action per turn
- Ways to amplify copied effects (play them at bonus value)

**Key novel card ideas:**
- **Mimic** (1 AP) — Replay the last effect any character used this turn, with the bard as the caster and original target as target. Cheap and immediate echo.
- **Plagiarize** (2 AP) — Take a random card from target's hand. Play it immediately at full value. Both steals and uses in one action.
- **Echo Chamber** (2 AP) — Buff: for 2 turns, the first card each enemy plays is automatically copied and replayed by the bard against the same target at half value. Passive mirroring.
- **Perfect Copy** (3 AP) — Replay the highest-AP card used by any character this game at full value. The ultimate — copy the most powerful thing that's happened so far.
- **Mockery** (1 AP) — Deal `0` damage. But if the target used a damage card last turn, deal damage equal to what they dealt. Punishes aggression by reflecting it.

**Formula hook:** `last_effect` and `last_card_played_value` tracked on `current_turn` (proposed in Necromancer doc). `Perfect Copy` needs a game-wide history of card plays, extending the `last_effect` concept into a `play_history` list on `CombatState`.

---

## Strategy 4: Rhythm (AP manipulation)

**Concept:** The bard plays cheap cards in precise sequences to generate AP faster than they spend it, creating "free" turns where more cards are played than AP should allow. Cards that refund AP on play, cards that cost 0 AP if played as the Nth card this turn, and a grand payoff where the bard takes an extra turn entirely.

**Wants:**
- 0 AP cost cards (played for free under certain conditions)
- Cards that refund 1 AP when played
- A counter tracking how many cards have been played this turn
- An extra-turn card as the ultimate payoff

**Key novel card ideas:**
- **Quick Note** (0 AP) — Deal 2 damage. The bard's 0-cost filler — free to spam but weak alone.
- **Riff** (1 AP) — Deal 3 damage. Refund 1 AP if this is the 2nd or later card played this turn. Starts paying for itself after the first card.
- **Improvise** (0 AP) — Draw 1 card. Can only be played if you've already played 2+ cards this turn. The reward for a busy turn.
- **Standing Ovation** (2 AP) — If you've played 4+ cards this turn, deal 12 damage. Otherwise deal 3. The rhythm payoff — the deck builds toward hitting 4 cards in a turn.
- **Encore Turn** (3 AP) — After your turn ends normally, take one additional mini-turn: draw 3 cards and play 1 for free. The ultimate AP manipulation — an extra partial turn.

**New mechanic needed:** `cards_played_this_turn` counter on `current_turn` (increment in `process_card`). AP refund after card play — a post-effect step that adds AP back to `current_turn.player`. `Encore Turn` is the most complex: after `rotate_queue` fires, inject one more partial turn for the bard before the next player acts.

---

## Strategy 5: Storyteller (Narrative win conditions)

**Concept:** The bard wins by fulfilling specific "story" conditions — playing a set of thematically linked cards in sequence within a game. Complete Act 1 (play 3 "verse" cards), and Act 2 cards unlock with bonus effects. Complete Act 2, and the finale becomes playable. A quest structure embedded in the deck.

**Wants:**
- Card tags ("verse", "chorus", "bridge") tracked as progress counters
- Cards whose effects improve if their "act" prerequisites are met
- A win condition card that can only be played after both acts
- Enough card draw to reliably assemble the sequence in time

**Key novel card ideas:**
- **Verse I** (1 AP) — Deal 3 damage. Tag: `verse`. Increments `verse_count` on `current_turn.player` status.
- **Verse II** (1 AP) — Heal an ally 4 HP. Tag: `verse`. Same counter increment.
- **Verse III** (1 AP) — Apply `shield: 3` to self. Tag: `verse`.
- **Chorus** (2 AP) — Only playable after 3 `verse` cards have been played this game. Deal 8 damage to all enemies. Tags as `chorus` and unlocks the finale.
- **The Grand Ballad** (3 AP) — Only playable after `chorus` has been played. Deal 15 damage to all enemies and heal all allies for 10. The narrative climax — requires the full story to be told first.

**New mechanic needed:** Card tags and a progress tracker — `verse_count`, `chorus_played` as persistent status effects on the character (stacking/boolean). The card play hook in `process_card` increments the relevant counter after each tagged card resolves. `Chorus` and `The Grand Ballad` use targeting rules that gate playability on counter values (`verse_count >= 3`).

---

## Mechanic summary: what's needed to unlock these

| Mechanic | Status | Strategy |
|----------|--------|----------|
| `grant_ap` effect targeting an ally | Novel, shared with Ranger Beastmaster + Monk | Inspiration Engine |
| `damage_bonus` buff status (consumed on next hit) | Novel — modifier in damage pipeline | Inspiration Engine |
| `last_effect` on `current_turn` | Novel, shared with Necromancer Dark Echo | Inspiration Engine, Copycat |
| `silenced` status (block card play) | Novel — checked in `process_action(:pick_card)` | Dissonance |
| `confused` status (random retargeting) | Novel — intercepts target selection in `process_card` | Dissonance |
| `charmed` status (must attack specific target) | Novel variant of `taunt` | Dissonance |
| `play_history` game-wide card log | Novel extension of `last_effect` | Copycat |
| `cards_played_this_turn` counter | Novel — increment in `process_card` | Rhythm |
| AP refund post-card-play | Novel — post-effect AP addition step | Rhythm |
| `Encore Turn` (extra partial turn) | Novel — inject extra turn after `rotate_queue` | Rhythm |
| Card tags + progress counters | Novel — stacking status tracking per-card-type plays | Storyteller |
| Playability gates (targeting rule on card play) | Already expressible via targeting rules | Storyteller |
