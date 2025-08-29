# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Game.Repo.insert!(%Game.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Game.{Repo, BaseCards.BaseCard, BaseDecks.BaseDeck, Content.BaseDeckCard}

# Base/Common Cards
Repo.insert!(%BaseCard{
  name: "Strike",
  headline: "A basic melee attack",
  ap: 1,
  effects: [%{type: "damage", value: 5}],
  rarity: :common
})

Repo.insert!(%BaseCard{
  name: "Defend",
  headline: "Take a defensive stance",
  ap: 1,
  effects: [%{type: "shield", value: 3}],
  rarity: :common
})

# Mage Cards
Repo.insert!(%BaseCard{
  name: "Fireball",
  headline: "Launches a ball of fire at an enemy",
  ap: 2,
  effects: [%{type: "damage", value: 8}],
  rarity: :uncommon
})

Repo.insert!(%BaseCard{
  name: "Icicle",
  headline: "Deals damage and slows the target",
  ap: 1,
  effects: [%{type: "damage", value: 1}, %{type: "slow", value: 1}],
  rarity: :uncommon
})

Repo.insert!(%BaseCard{
  name: "Lightning Bolt",
  headline: "Strikes an enemy with a bolt of lightning",
  ap: 2,
  effects: [%{type: "damage", value: 7}, %{type: "stun", value: 1}],
  rarity: :rare
})

Repo.insert!(%BaseCard{
  name: "Arcane Explosion",
  headline: "Damages all nearby enemies",
  ap: 3,
  effects: [%{type: "damage", value: 6, aoe: true}],
  rarity: :rare
})

Repo.insert!(%BaseCard{
  name: "Mana Shield",
  headline: "Creates a protective barrier around the caster",
  ap: 1,
  effects: [%{type: "shield", value: 5}, %{type: "draw", value: 1}],
  rarity: :uncommon
})

# Ranger/Archer Cards
Repo.insert!(%BaseCard{
  name: "Shot",
  headline: "A precise ranged attack",
  ap: 1,
  effects: [%{type: "damage", value: 5, range: 5}],
  rarity: :common
})

Repo.insert!(%BaseCard{
  name: "Multishot",
  headline: "Fires multiple arrows at once",
  ap: 2,
  effects: [%{type: "damage", value: 3, multi: 3, range: 4}],
  rarity: :uncommon
})

Repo.insert!(%BaseCard{
  name: "Poison Arrow",
  headline: "Coats an arrow with deadly poison",
  ap: 2,
  effects: [%{type: "damage", value: 3}, %{type: "poison", value: 2}],
  rarity: :uncommon
})

Repo.insert!(%BaseCard{
  name: "Snipe",
  headline: "A powerful shot from long distance",
  ap: 3,
  effects: [%{type: "damage", value: 12, range: 6}],
  rarity: :rare
})

# Warrior/Fighter Cards
Repo.insert!(%BaseCard{
  name: "Cleave",
  headline: "A sweeping attack that hits multiple enemies",
  ap: 2,
  effects: [%{type: "damage", value: 4, aoe: true}],
  rarity: :uncommon
})

Repo.insert!(%BaseCard{
  name: "Block",
  headline: "Raises shield to block incoming attacks",
  ap: 1,
  effects: [%{type: "shield", value: 5}],
  rarity: :common
})

Repo.insert!(%BaseCard{
  name: "Execute",
  headline: "Finishes off a wounded enemy",
  ap: 2,
  effects: [%{type: "damage", value: 6, scaling: "enemy_missing_health"}],
  rarity: :uncommon
})

Repo.insert!(%BaseCard{
  name: "Whirlwind",
  headline: "Spin around, hitting all nearby enemies",
  ap: 3,
  effects: [%{type: "damage", value: 7, aoe: true}],
  rarity: :rare
})

# Rogue/Thief Cards
Repo.insert!(%BaseCard{
  name: "Backstab",
  headline: "Strike an enemy from behind for massive damage",
  ap: 1,
  effects: [%{type: "damage", value: 3, conditional: %{type: "position", bonus: 7}}],
  rarity: :uncommon
})

Repo.insert!(%BaseCard{
  name: "Evade",
  headline: "Quickly move out of harm's way",
  ap: 1,
  effects: [%{type: "dodge", value: 1}, %{type: "move", value: 2}],
  rarity: :uncommon
})

Repo.insert!(%BaseCard{
  name: "Shadowstrike",
  headline: "A quick strike from the shadows",
  ap: 2,
  effects: [%{type: "damage", value: 6}, %{type: "stealth", value: 1}],
  rarity: :rare
})

Repo.insert!(%BaseCard{
  name: "Poison Dagger",
  headline: "Apply deadly poison to your target",
  ap: 1,
  effects: [%{type: "damage", value: 2}, %{type: "poison", value: 3}],
  rarity: :uncommon
})

# Cleric/Healer Cards
Repo.insert!(%BaseCard{
  name: "Heal",
  headline: "Restore health to a friendly target",
  ap: 1,
  effects: [%{type: "heal", value: 5}],
  rarity: :common
})

Repo.insert!(%BaseCard{
  name: "Group Heal",
  headline: "Heal all nearby allies",
  ap: 3,
  effects: [%{type: "heal", value: 3, aoe: true}],
  rarity: :rare
})

Repo.insert!(%BaseCard{
  name: "Purify",
  headline: "Remove debuffs from an ally",
  ap: 1,
  effects: [%{type: "cleanse", value: 1}, %{type: "heal", value: 2}],
  rarity: :uncommon
})

Repo.insert!(%BaseCard{
  name: "Divine Shield",
  headline: "Summon divine protection for an ally",
  ap: 2,
  effects: [%{type: "shield", value: 7}, %{type: "heal", value: 1}],
  rarity: :rare
})

# Paladin Cards
Repo.insert!(%BaseCard{
  name: "Holy Strike",
  headline: "Strikes an enemy with holy power",
  ap: 1,
  effects: [%{type: "damage", value: 4}, %{type: "heal", value: 2}],
  rarity: :uncommon
})

Repo.insert!(%BaseCard{
  name: "Righteous Defense",
  headline: "Bolsters defenses with divine power",
  ap: 2,
  effects: [%{type: "shield", value: 8}, %{type: "taunt", value: 1}],
  rarity: :uncommon
})

Repo.insert!(%BaseCard{
  name: "Consecration",
  headline: "Consecrates the ground, damaging enemies and healing allies",
  ap: 3,
  effects: [%{type: "damage", value: 5, aoe: true}, %{type: "heal", value: 3, aoe: true}],
  rarity: :rare
})

# Druid Cards
Repo.insert!(%BaseCard{
  name: "Entangling Roots",
  headline: "Roots an enemy in place",
  ap: 2,
  effects: [%{type: "root", value: 2}, %{type: "damage", value: 2}],
  rarity: :uncommon
})

Repo.insert!(%BaseCard{
  name: "Rejuvenation",
  headline: "Heals the target over time",
  ap: 1,
  effects: [%{type: "heal", value: 2}, %{type: "regen", value: 3}],
  rarity: :uncommon
})

Repo.insert!(%BaseCard{
  name: "Wild Growth",
  headline: "Accelerates natural healing",
  ap: 2,
  effects: [%{type: "heal", value: 3}, %{type: "growth", value: 2}],
  rarity: :uncommon
})

Repo.insert!(%BaseCard{
  name: "Moonfire",
  headline: "Burns the target with lunar energy",
  ap: 1,
  effects: [%{type: "damage", value: 3}, %{type: "burn", value: 2}],
  rarity: :common
})

# Create base decks for each class
# Warrior Deck
{:ok, warrior_deck} = Repo.insert(%BaseDeck{name: "Warrior Starter"})

# Mage Deck
{:ok, mage_deck} = Repo.insert(%BaseDeck{name: "Mage Starter"})

# Ranger Deck
{:ok, ranger_deck} = Repo.insert(%BaseDeck{name: "Ranger Starter"})

# Rogue Deck
{:ok, rogue_deck} = Repo.insert(%BaseDeck{name: "Rogue Starter"})

# Cleric Deck
{:ok, cleric_deck} = Repo.insert(%BaseDeck{name: "Cleric Starter"})

# Paladin Deck
{:ok, paladin_deck} = Repo.insert(%BaseDeck{name: "Paladin Starter"})

# Druid Deck
{:ok, druid_deck} = Repo.insert(%BaseDeck{name: "Druid Starter"})

# Function to find card IDs by name after they've been inserted
find_card_id = fn name ->
  Repo.one(from c in BaseCard, where: c.name == ^name, select: c.id)
end

# Associate cards with decks

# Warrior Deck Cards (15 total)
Repo.insert!(%BaseDeckCard{deck_id: warrior_deck.id, card_id: find_card_id.("Strike"), count: 4})
Repo.insert!(%BaseDeckCard{deck_id: warrior_deck.id, card_id: find_card_id.("Cleave"), count: 3})
Repo.insert!(%BaseDeckCard{deck_id: warrior_deck.id, card_id: find_card_id.("Block"), count: 4})
Repo.insert!(%BaseDeckCard{deck_id: warrior_deck.id, card_id: find_card_id.("Execute"), count: 2})

Repo.insert!(%BaseDeckCard{
  deck_id: warrior_deck.id,
  card_id: find_card_id.("Whirlwind"),
  count: 2
})

# Mage Deck Cards (15 total)
Repo.insert!(%BaseDeckCard{deck_id: mage_deck.id, card_id: find_card_id.("Fireball"), count: 4})
Repo.insert!(%BaseDeckCard{deck_id: mage_deck.id, card_id: find_card_id.("Icicle"), count: 3})

Repo.insert!(%BaseDeckCard{
  deck_id: mage_deck.id,
  card_id: find_card_id.("Lightning Bolt"),
  count: 2
})

Repo.insert!(%BaseDeckCard{
  deck_id: mage_deck.id,
  card_id: find_card_id.("Arcane Explosion"),
  count: 2
})

Repo.insert!(%BaseDeckCard{
  deck_id: mage_deck.id,
  card_id: find_card_id.("Mana Shield"),
  count: 4
})

# Ranger Deck Cards (15 total)
Repo.insert!(%BaseDeckCard{deck_id: ranger_deck.id, card_id: find_card_id.("Shot"), count: 5})

Repo.insert!(%BaseDeckCard{
  deck_id: ranger_deck.id,
  card_id: find_card_id.("Multishot"),
  count: 3
})

Repo.insert!(%BaseDeckCard{
  deck_id: ranger_deck.id,
  card_id: find_card_id.("Poison Arrow"),
  count: 3
})

Repo.insert!(%BaseDeckCard{deck_id: ranger_deck.id, card_id: find_card_id.("Snipe"), count: 2})
Repo.insert!(%BaseDeckCard{deck_id: ranger_deck.id, card_id: find_card_id.("Evade"), count: 2})

# Rogue Deck Cards (15 total)
Repo.insert!(%BaseDeckCard{deck_id: rogue_deck.id, card_id: find_card_id.("Strike"), count: 3})
Repo.insert!(%BaseDeckCard{deck_id: rogue_deck.id, card_id: find_card_id.("Backstab"), count: 4})
Repo.insert!(%BaseDeckCard{deck_id: rogue_deck.id, card_id: find_card_id.("Evade"), count: 3})

Repo.insert!(%BaseDeckCard{
  deck_id: rogue_deck.id,
  card_id: find_card_id.("Shadowstrike"),
  count: 2
})

Repo.insert!(%BaseDeckCard{
  deck_id: rogue_deck.id,
  card_id: find_card_id.("Poison Dagger"),
  count: 3
})

# Cleric Deck Cards (15 total)
Repo.insert!(%BaseDeckCard{deck_id: cleric_deck.id, card_id: find_card_id.("Heal"), count: 5})
Repo.insert!(%BaseDeckCard{deck_id: cleric_deck.id, card_id: find_card_id.("Strike"), count: 2})

Repo.insert!(%BaseDeckCard{
  deck_id: cleric_deck.id,
  card_id: find_card_id.("Group Heal"),
  count: 2
})

Repo.insert!(%BaseDeckCard{deck_id: cleric_deck.id, card_id: find_card_id.("Purify"), count: 3})

Repo.insert!(%BaseDeckCard{
  deck_id: cleric_deck.id,
  card_id: find_card_id.("Divine Shield"),
  count: 3
})

# Paladin Deck Cards (15 total)
Repo.insert!(%BaseDeckCard{deck_id: paladin_deck.id, card_id: find_card_id.("Strike"), count: 3})

Repo.insert!(%BaseDeckCard{
  deck_id: paladin_deck.id,
  card_id: find_card_id.("Holy Strike"),
  count: 3
})

Repo.insert!(%BaseDeckCard{
  deck_id: paladin_deck.id,
  card_id: find_card_id.("Righteous Defense"),
  count: 3
})

Repo.insert!(%BaseDeckCard{
  deck_id: paladin_deck.id,
  card_id: find_card_id.("Consecration"),
  count: 2
})

Repo.insert!(%BaseDeckCard{deck_id: paladin_deck.id, card_id: find_card_id.("Heal"), count: 2})

Repo.insert!(%BaseDeckCard{
  deck_id: paladin_deck.id,
  card_id: find_card_id.("Divine Shield"),
  count: 2
})

# Druid Deck Cards (15 total)
Repo.insert!(%BaseDeckCard{
  deck_id: druid_deck.id,
  card_id: find_card_id.("Entangling Roots"),
  count: 3
})

Repo.insert!(%BaseDeckCard{
  deck_id: druid_deck.id,
  card_id: find_card_id.("Rejuvenation"),
  count: 3
})

Repo.insert!(%BaseDeckCard{
  deck_id: druid_deck.id,
  card_id: find_card_id.("Wild Growth"),
  count: 3
})

Repo.insert!(%BaseDeckCard{deck_id: druid_deck.id, card_id: find_card_id.("Moonfire"), count: 4})
Repo.insert!(%BaseDeckCard{deck_id: druid_deck.id, card_id: find_card_id.("Heal"), count: 2})
