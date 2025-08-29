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

alias Game.{Repo, Card}

# Base/Common Cards
Repo.insert!(%Card{
  id: 100,
  name: "Strike",
  description: "A basic melee attack",
  cost: 1,
  effects: [{:damage, 5}],
  range: 1,
  targeting: :single,
  rarity: :common
})

Repo.insert!(%Card{
  id: 101,
  name: "Defend",
  description: "Take a defensive stance",
  cost: 1,
  effects: [{:shield, 3}],
  targeting: :self,
  rarity: :common
})

# Mage Cards
Repo.insert!(%Card{
  id: 200,
  name: "Fireball",
  description: "Launches a ball of fire at an enemy",
  cost: 2,
  effects: [{:damage, 8}],
  range: 3,
  targeting: :single,
  rarity: :uncommon,
  element: :fire
})

Repo.insert!(%Card{
  id: 201,
  name: "Icicle",
  description: "Deals damage and slows the target",
  cost: 1,
  effects: [{:damage, 1}, {:slow, 1}],
  range: 2,
  targeting: :single,
  rarity: :uncommon,
  element: :ice
})

Repo.insert!(%Card{
  id: 202,
  name: "Lightning Bolt",
  description: "Strikes an enemy with a bolt of lightning",
  cost: 2,
  effects: [{:damage, 7}, {:stun, 1}],
  range: 4,
  targeting: :single,
  rarity: :rare,
  element: :lightning
})

Repo.insert!(%Card{
  id: 203,
  name: "Arcane Explosion",
  description: "Damages all nearby enemies",
  cost: 3,
  effects: [{:damage, 6}],
  range: 2,
  targeting: :aoe,
  rarity: :rare,
  element: :arcane
})

Repo.insert!(%Card{
  id: 204,
  name: "Mana Shield",
  description: "Creates a protective barrier around the caster",
  cost: 1,
  effects: [{:shield, 5}, {:draw, 1}],
  targeting: :self,
  rarity: :uncommon,
  element: :arcane
})

# Ranger/Archer Cards
Repo.insert!(%Card{
  id: 300,
  name: "Shot",
  description: "A precise ranged attack",
  cost: 1,
  effects: [{:damage, 5}],
  range: 5,
  targeting: :single,
  rarity: :common
})

Repo.insert!(%Card{
  id: 301,
  name: "Multishot",
  description: "Fires multiple arrows at once",
  cost: 2,
  effects: [{:damage, 3}],
  range: 4,
  targeting: :aoe,
  rarity: :uncommon,
  multi_strike: 3
})

Repo.insert!(%Card{
  id: 302,
  name: "Poison Arrow",
  description: "Coats an arrow with deadly poison",
  cost: 2,
  effects: [{:damage, 3}, {:poison, 2}],
  range: 4,
  targeting: :single,
  rarity: :uncommon,
  conditional_effects: [{:on_hit, {:poison, 3}}]
})

Repo.insert!(%Card{
  id: 303,
  name: "Snipe",
  description: "A powerful shot from long distance",
  cost: 3,
  effects: [{:damage, 12}],
  range: 6,
  targeting: :single,
  rarity: :rare,
  conditional_effects: [{:if_unaware, {:damage, 18}}]
})

# Warrior/Fighter Cards
Repo.insert!(%Card{
  id: 400,
  name: "Cleave",
  description: "A sweeping attack that hits multiple enemies",
  cost: 2,
  effects: [{:damage, 4}],
  range: 1,
  targeting: :aoe,
  rarity: :uncommon
})

Repo.insert!(%Card{
  id: 401,
  name: "Block",
  description: "Raises shield to block incoming attacks",
  cost: 1,
  effects: [{:shield, 5}],
  targeting: :self,
  rarity: :common
})

Repo.insert!(%Card{
  id: 402,
  name: "Execute",
  description: "Finishes off a wounded enemy",
  cost: 2,
  effects: [{:damage, 6}],
  range: 1,
  targeting: :single,
  rarity: :uncommon,
  scaling: {:enemy_missing_health, 0.5}
})

Repo.insert!(%Card{
  id: 403,
  name: "Whirlwind",
  description: "Spin around, hitting all nearby enemies",
  cost: 3,
  effects: [{:damage, 7}],
  range: 1,
  targeting: :aoe,
  rarity: :rare
})

# Rogue/Thief Cards
Repo.insert!(%Card{
  id: 500,
  name: "Backstab",
  description: "Strike an enemy from behind for massive damage",
  cost: 1,
  effects: [{:damage, 3}],
  range: 1,
  targeting: :single,
  rarity: :uncommon,
  conditional_effects: [{:if_behind, {:damage, 7}}]
})

Repo.insert!(%Card{
  id: 501,
  name: "Evade",
  description: "Quickly move out of harm's way",
  cost: 1,
  effects: [{:dodge, 1}, {:move, 2}],
  targeting: :self,
  rarity: :uncommon
})

Repo.insert!(%Card{
  id: 502,
  name: "Shadowstrike",
  description: "A quick strike from the shadows",
  cost: 2,
  effects: [{:damage, 6}, {:stealth, 1}],
  range: 1,
  targeting: :single,
  rarity: :rare,
  element: :shadow
})

Repo.insert!(%Card{
  id: 503,
  name: "Poison Dagger",
  description: "Apply deadly poison to your target",
  cost: 1,
  effects: [{:damage, 2}, {:poison, 3}],
  range: 1,
  targeting: :single,
  rarity: :uncommon
})

# Cleric/Healer Cards
Repo.insert!(%Card{
  id: 600,
  name: "Heal",
  description: "Restore health to a friendly target",
  cost: 1,
  effects: [{:heal, 5}],
  range: 2,
  targeting: :single,
  rarity: :common,
  element: :light
})

Repo.insert!(%Card{
  id: 601,
  name: "Group Heal",
  description: "Heal all nearby allies",
  cost: 3,
  effects: [{:heal, 3}],
  range: 2,
  targeting: :aoe,
  rarity: :rare,
  element: :light
})

Repo.insert!(%Card{
  id: 602,
  name: "Purify",
  description: "Remove debuffs from an ally",
  cost: 1,
  effects: [{:cleanse, 1}, {:heal, 2}],
  range: 2,
  targeting: :single,
  rarity: :uncommon,
  element: :light
})

Repo.insert!(%Card{
  id: 603,
  name: "Divine Shield",
  description: "Summon divine protection for an ally",
  cost: 2,
  effects: [{:shield, 7}, {:heal, 1}],
  range: 2,
  targeting: :single,
  rarity: :rare,
  element: :light
})

# Paladin Cards
Repo.insert!(%Card{
  id: 700,
  name: "Holy Strike",
  description: "Strikes an enemy with holy power",
  cost: 1,
  effects: [{:damage, 4}, {:heal, 2}],
  range: 1,
  targeting: :single,
  rarity: :uncommon,
  element: :light
})

Repo.insert!(%Card{
  id: 701,
  name: "Righteous Defense",
  description: "Bolsters defenses with divine power",
  cost: 2,
  effects: [{:shield, 8}, {:taunt, 1}],
  targeting: :self,
  rarity: :uncommon,
  element: :light
})

Repo.insert!(%Card{
  id: 702,
  name: "Consecration",
  description: "Consecrates the ground, damaging enemies and healing allies",
  cost: 3,
  effects: [{:damage, 5}, {:heal, 3}],
  range: 2,
  targeting: :aoe,
  rarity: :rare,
  element: :light
})

# Druid Cards
Repo.insert!(%Card{
  id: 800,
  name: "Entangling Roots",
  description: "Roots an enemy in place",
  cost: 2,
  effects: [{:root, 2}, {:damage, 2}],
  range: 3,
  targeting: :single,
  rarity: :uncommon,
  element: :nature
})

Repo.insert!(%Card{
  id: 801,
  name: "Rejuvenation",
  description: "Heals the target over time",
  cost: 1,
  effects: [{:heal, 2}, {:regen, 3}],
  range: 2,
  targeting: :single,
  rarity: :uncommon,
  element: :nature
})

Repo.insert!(%Card{
  id: 802,
  name: "Wild Growth",
  description: "Accelerates natural healing",
  cost: 2,
  effects: [{:heal, 3}, {:growth, 2}],
  range: 2,
  targeting: :single,
  rarity: :uncommon,
  element: :nature,
  scaling: {:turns_active, 1}
})

Repo.insert!(%Card{
  id: 803,
  name: "Moonfire",
  description: "Burns the target with lunar energy",
  cost: 1,
  effects: [{:damage, 3}, {:burn, 2}],
  range: 3,
  targeting: :single,
  rarity: :common,
  element: :nature
})
