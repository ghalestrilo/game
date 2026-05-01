# Necromancer Deck Strategies

A design brainstorm for necromancer archetypes — what each strategy wants to do, what cards it needs, and what mechanics (existing or new) make it tick.

---

## Existing mechanics the necromancer can already exploit

| Mechanic | Card | Notes |
|----------|------|-------|
| Summon | Summon effect | Already implemented — spawns a character on the board with the caster's team |
| Poison / DoT | Poison Arrow, Poison Dagger (cross-class) | Damage-over-time fits the rot/decay theme |
| Discard | Discard effect | Strip enemy hand — flavored as "curse" |
| Execute scaling | Execute | Bonus on low-HP targets, flavored as finishing off the dying |
| Damage | Moonfire, Fireball (cross-class) | Generic damage shells to re-flavor as necrotic/shadow |
| Draw | Mana Shield, Flowing Form pattern | Cycle the deck to find key combo pieces |

---

## Strategy 1: Undead Horde (Board flooding)

**Concept:** Summon as many undead units as possible and overwhelm the enemy with numbers. Each individual undead is weak, but 4–5 on the board simultaneously is unmanageable. The necromancer itself stays far back, protected by the swarm, spending AP exclusively on summoning and buffing.

**Wants:**
- Cheap summon cards (the existing Summon effect costs 2 AP — needs cheaper variants)
- A way to resummon fallen undead (death as a resource)
- Cards that get stronger the more undead are on the field
- A way to sacrifice undead intentionally for large effects

**Key novel card ideas:**
- **Raise Skeleton** (1 AP) — Summons a Skeleton (new base class: 4 HP, 1 AP, 1 melee attack, no movement cards). The cheapest possible summon — the necromancer's bread and butter.
- **Reanimate** (2 AP) — Target a dead ally character anywhere on the board. Restore them with 50% HP. Requires tracking recently-dead characters — a `graveyard` list on combat state.
- **Dark Pact** (0 AP) — Sacrifice one of your undead (remove from board). Draw 3 cards. Turns disposable skeletons into card advantage.
- **Undying Tide** (3 AP) — Summon 2 Skeletons simultaneously. Late-game flood card.
- **Army of the Dead** (3 AP) — Deal `2 × number of undead on your team` damage to a single target. The horde's payoff — scales entirely off board presence.

**New mechanic needed:** A `graveyard` list on `CombatState` tracking characters removed this game, enabling Reanimate. `Dark Pact` needs a "sacrifice ally" targeting mode — target a friendly unit rather than an enemy. `Army of the Dead` needs a formula that counts allies of a specific class tag on the board.

---

## Strategy 2: Life Drain (Sustain through death)

**Concept:** Every point of damage dealt heals the necromancer. The deck is entirely self-sustaining — the necromancer never needs a dedicated heal card because attacks double as recovery. The longer the game goes, the harder the necromancer is to kill.

**Wants:**
- Cards that leech HP on hit
- High single-target damage to maximize leeched HP per hit
- DoT effects that also leech (poison that heals the caster each tick)
- Cards that amplify leech rate temporarily

**Key novel card ideas:**
- **Drain Life** (2 AP) — Deal 6 damage to target, heal self for 6. The core card — expensive but completely neutral on HP when it connects.
- **Soul Siphon** (1 AP) — Deal 3 damage, heal self for 3. The cheaper, weaker version — the reliable turn-1 play.
- **Vampiric Aura** (2 AP) — Buff: for the rest of this turn, all damage dealt heals the caster for 50% of the amount. Turns even weak hits into sustain.
- **Necrotic Poison** (2 AP) — Apply a poison variant that also heals the caster each time it ticks. A `leech_poison` status that triggers both `apply_damage` on the target and `apply_healing` on the caster each turn end.
- **Exsanguinate** (3 AP) — Deal damage equal to the difference between the necromancer's max HP and current HP. Rewards getting hurt — the lower the HP, the higher the spike. Formula: `%{"alias" => "caster_missing_hp"}`.

**Formula hook:** `caster_missing_hp` alias already exists in seeds. `Exsanguinate` is a direct drop-in. `Vampiric Aura` needs a new buff status that modifies the damage effect pipeline — after damage is applied, a separate healing step fires for the caster. Leech poison is a variant of the poison DoT tick that also calls `apply_healing` on the owner.

---

## Strategy 3: Curse Weaver (Debuff control)

**Concept:** Layer multiple curses on enemies before they can act. Individually each curse is minor, but three or four stacked together make a target unable to function — reduced AP, forced discards, reversed healing, and damage amplification. Win by making enemies irrelevant rather than killing them outright.

**Wants:**
- Multiple distinct debuff types that stack independently
- Cards that check how many curses a target has (combo potential)
- A "harvest" card that consumes all curses for a massive effect
- Cards that spread curses from one target to adjacent enemies

**Key novel card ideas:**
- **Enfeeble** (1 AP) — Apply `weakened: 1` (target loses 1 AP next turn). The fundamental AP tax curse.
- **Hex** (1 AP) — Apply `hexed: 1` (target's heals are converted to damage for 1 turn). Devastating against clerics and paladins.
- **Wither** (1 AP) — Apply `withered: 1` (target's max HP is reduced by 3 for 2 turns). Doesn't deal immediate damage but shrinks their effective HP pool.
- **Plague** (2 AP) — Copy all curses from the target onto all adjacent enemies. Curse spreading — one well-set-up target contaminates the whole cluster.
- **Soul Harvest** (3 AP) — Remove all curses from the target. Deal `8 × number of curses removed` damage. The all-in payoff — optimal after 3–4 curse applications.

**New mechanic needed:** `hexed` as a status that intercepts `apply_healing` and converts it to damage — a modifier hook on the healing pipeline, symmetric with how `vulnerable` modifies the damage pipeline. `Wither` needs a max HP reduction status (temporary `max_hp` override, restored when the effect expires). Soul Harvest needs to count and remove status effects by a "curse" tag.

---

## Strategy 4: Death Ritual (Sacrifice engine)

**Concept:** The necromancer's own HP is a resource. Spend it recklessly on powerful ritual cards, then recoup through life drain or by sacrificing summoned undead. Every near-death experience unlocks more powerful cards — the deck peaks when the necromancer is at 1 HP.

**Wants:**
- Cards with HP costs instead of (or in addition to) AP costs
- Cards that scale with missing HP (`caster_missing_hp` alias)
- Survival tools to stay alive after spending HP (shields, heals, undead absorbing hits)
- A win condition that fires if the necromancer survives below a threshold

**Key novel card ideas:**
- **Blood Ritual** (0 AP) — Pay 4 HP. Draw 3 cards. The engine — costs no AP, costs life. Lets the necromancer burn through the deck while managing HP as a second resource.
- **Dark Offering** (1 AP) — Pay 6 HP. Summon a Bone Knight (new base class: 10 HP, 2 AP, stronger melee). Higher HP cost for a more powerful summon.
- **Death's Door** (2 AP) — Can only be played at 25% HP or below. Deal 20 damage to target. The ultimate desperation card — an instant kill threat that the opponent has to respect from the moment the necromancer drops low.
- **Lichform** (3 AP) — Pay 10 HP. For 2 turns, all cards cost 0 AP. The ritual transformation — burn HP for an entire turn of free actions.
- **Undying Will** (0 AP) — If the necromancer would die this turn, instead survive at 1 HP. Can only trigger once per game. A single insurance card that makes the whole HP-as-resource strategy viable.

**Formula hook:** `caster_missing_hp` alias already seeded. `Death's Door` uses a targeting rule that checks `caster.hp ≤ caster.max_hp × 0.25`. `Lichform` needs a new `free_cards` buff status that overrides AP cost during resolution. HP costs need a new resolution step in `process_card` — check and spend HP before effects fire, similar to how AP is spent.

---

## Strategy 5: Bone Architect (Undead synergy engine)

**Concept:** Rather than flooding the board with cheap undead, summon a small number of specific undead units and then upgrade them with enchantment cards. A single Skeleton empowered with three buffs becomes a greater threat than five vanilla ones. Quality over quantity — the antithesis of the Horde strategy.

**Wants:**
- A few high-quality summon targets (Bone Knight, Death Knight base classes)
- Cards that target a friendly undead and enhance their stats or add new effects
- Cards that let undead act twice in one turn
- A way to merge two weak undead into one strong one

**Key novel card ideas:**
- **Empower Undead** (1 AP) — Target a friendly undead. Their next attack deals double damage. Single-use buff delivered from the necromancer's hand.
- **Bone Armor** (1 AP) — Target a friendly undead. Apply `shield: 6` to them. Makes the undead frontliner significantly harder to remove.
- **Animate Weapon** (2 AP) — Target a friendly undead. They immediately take a free turn action (draw and play one card from their deck, or make one basic attack if AI). Doubles their output for one round.
- **Soul Transfer** (2 AP) — Sacrifice two friendly undead. Summon one Death Knight (new base class: inherits combined HP of both sacrificed units, capped at 20). Merging mechanic — compress two weak units into one powerful one.
- **Phylactery** (2 AP) — Enchant a friendly undead. When they die, they respawn on the same tile with 4 HP after 1 turn. Needs a triggered resurrection mechanic on death — the `graveyard` system from Strategy 1 handles the tracking.

**New mechanic needed:** Enchanting a specific ally (not just "target character") requires ally-targeting cards, which are already expressible via targeting rules (`caster.team === target.team`). Free turn action (`Animate Weapon`) shares the `grant_ap` / `free_action` effect type proposed in the Ranger Beastmaster doc. `Soul Transfer` needs access to the stats of the two sacrificed units at resolution time — complex targeting (multi-select), possibly the most technically involved card in any of these docs.

---

## Mechanic summary: what's needed to unlock these

| Mechanic | Status | Strategy |
|----------|--------|----------|
| Summon effect | **Done** | Horde, Bone Architect |
| `caster_missing_hp` alias | **Done** (seeded) | Life Drain, Death Ritual |
| Poison DoT tick | Needs implementation (shared with Ranger, Monk) | Life Drain |
| `graveyard` list on CombatState | Novel — track removed characters | Horde, Bone Architect |
| Sacrifice ally targeting mode | Novel targeting rule — target friendly unit to remove it | Horde, Death Ritual |
| `army_of_dead` count alias | Novel alias counting allies by class tag | Horde |
| Leech (heal-on-damage) | Novel — post-damage hook calling `apply_healing` on caster | Life Drain |
| `leech_poison` variant | Novel — DoT tick that also heals caster | Life Drain |
| `hexed` status (convert heals to damage) | Novel — intercept `apply_healing` pipeline | Curse Weaver |
| `withered` status (reduce max HP) | Novel — temporary `max_hp` override | Curse Weaver |
| Curse tag + Soul Harvest count | Novel — mark certain effects as "curses", count on removal | Curse Weaver |
| HP cost on cards | Novel — spend HP in `process_card` before effects fire | Death Ritual |
| `free_cards` buff (0 AP turns) | Novel buff status overriding AP cost at resolution | Death Ritual |
| `Undying Will` (survive-at-1 trigger) | Novel — reactive trigger on the death check in `check_target_death` | Death Ritual |
| Ally enchantment cards | Ally targeting (already expressible via targeting rules) | Bone Architect |
| `grant_ap` / free-action effect | Novel, shared with Ranger Beastmaster | Bone Architect |
| Phylactery respawn trigger | Novel — triggered resurrection on death, uses graveyard system | Bone Architect |
