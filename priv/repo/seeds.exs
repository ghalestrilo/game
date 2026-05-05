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

# Define all base cards
cards = [
  # Base/Common Cards
  %{
    name: "Strike",
    headline: "A basic melee attack",
    ap: 1,
    effects: [%{type: "damage", value: 5}],
    rarity: :common
  },
  %{
    name: "Defend",
    headline: "Take a defensive stance",
    ap: 1,
    effects: [%{type: "shield", value: 3}],
    rarity: :common
  },

  # Mage Cards
  %{
    name: "Fireball",
    headline: "Launches a ball of fire at an enemy",
    ap: 2,
    effects: [%{type: "damage", value: 8}],
    rarity: :uncommon
  },
  %{
    name: "Icicle",
    headline: "Deals damage and slows the target",
    ap: 1,
    effects: [%{type: "damage", value: 1}, %{type: "slow", value: 1}],
    rarity: :uncommon
  },
  %{
    name: "Lightning Bolt",
    headline: "Strikes an enemy with a bolt of lightning",
    ap: 2,
    effects: [%{type: "damage", value: 7}, %{type: "stun", value: 1}],
    rarity: :rare
  },
  %{
    name: "Arcane Explosion",
    headline: "Damages all nearby enemies",
    ap: 3,
    effects: [%{type: "damage", value: 6, aoe: true}],
    rarity: :rare
  },
  %{
    name: "Mana Shield",
    headline: "Creates a protective barrier around the caster",
    ap: 1,
    effects: [%{type: "shield", value: 5}, %{type: "draw", value: 1}],
    rarity: :uncommon
  },

  # Ranger/Archer Cards
  %{
    name: "Shot",
    headline: "A precise ranged attack",
    ap: 1,
    effects: [%{type: "damage", value: 5, range: 5}],
    rarity: :common
  },
  %{
    name: "Multishot",
    headline: "Fires multiple arrows at once",
    ap: 2,
    effects: [%{type: "damage", value: 3, multi: 3, range: 4}],
    rarity: :uncommon
  },
  %{
    name: "Poison Arrow",
    headline: "Coats an arrow with deadly poison",
    ap: 2,
    effects: [%{type: "damage", value: 3}, %{type: "poison", value: 2}],
    rarity: :uncommon
  },
  %{
    name: "Snipe",
    headline: "A powerful shot from long distance",
    ap: 3,
    effects: [%{type: "damage", value: 12, range: 6}],
    rarity: :rare
  },

  # Warrior/Fighter Cards
  %{
    name: "Cleave",
    headline: "A sweeping attack that hits multiple enemies",
    ap: 2,
    effects: [%{type: "damage", value: 4, aoe: true}],
    rarity: :uncommon
  },
  %{
    name: "Block",
    headline: "Raises shield to block incoming attacks",
    ap: 1,
    effects: [%{type: "shield", value: 5}],
    rarity: :common
  },
  %{
    name: "Execute",
    headline: "Finishes off a wounded enemy",
    ap: 2,
    effects: [%{type: "damage", value: 6, scaling: "enemy_missing_health"}],
    rarity: :uncommon
  },
  %{
    name: "Whirlwind",
    headline: "Spin around, hitting all nearby enemies",
    ap: 3,
    effects: [%{type: "damage", value: 7, aoe: true}],
    rarity: :rare
  },

  # Rogue/Thief Cards
  %{
    name: "Backstab",
    headline: "Strike an enemy from behind for massive damage",
    ap: 1,
    effects: [%{type: "damage", value: %{"if" => [%{"alias" => "caster_is_hidden"}, 10, 3]}}],
    rarity: :uncommon
  },
  %{
    name: "Evade",
    headline: "Quickly move out of harm's way",
    ap: 1,
    effects: [%{type: "dodge", value: 1}, %{type: "move", value: 2}],
    rarity: :uncommon
  },
  %{
    name: "Shadowstrike",
    headline: "A quick strike from the shadows",
    ap: 2,
    effects: [%{type: "damage", value: 6}, %{type: "stealth", value: 1}],
    rarity: :rare
  },
  %{
    name: "Poison Dagger",
    headline: "Apply deadly poison to your target",
    ap: 1,
    effects: [%{type: "damage", value: 2}, %{type: "poison", value: 3}],
    rarity: :uncommon
  },

  # Cleric/Healer Cards
  %{
    name: "Heal",
    headline: "Restore health to a friendly target",
    ap: 1,
    effects: [%{type: "heal", value: 5}],
    rarity: :common
  },
  %{
    name: "Group Heal",
    headline: "Heal all nearby allies",
    ap: 3,
    effects: [%{type: "heal", value: 3, aoe: true}],
    rarity: :rare
  },
  %{
    name: "Purify",
    headline: "Remove debuffs from an ally",
    ap: 1,
    effects: [%{type: "cleanse", value: 1}, %{type: "heal", value: 2}],
    rarity: :uncommon
  },
  %{
    name: "Divine Shield",
    headline: "Summon divine protection for an ally",
    ap: 2,
    effects: [%{type: "shield", value: 7}, %{type: "heal", value: 1}],
    rarity: :rare
  },

  # Paladin Cards
  %{
    name: "Holy Strike",
    headline: "Strikes an enemy with holy power",
    ap: 1,
    effects: [%{type: "damage", value: 4}, %{type: "heal", value: 2}],
    rarity: :uncommon
  },
  %{
    name: "Righteous Defense",
    headline: "Bolsters defenses with divine power",
    ap: 2,
    effects: [%{type: "shield", value: 8}, %{type: "taunt", value: 1}],
    rarity: :uncommon
  },
  %{
    name: "Consecration",
    headline: "Consecrates the ground, damaging enemies and healing allies",
    ap: 3,
    effects: [%{type: "damage", value: 5, aoe: true}, %{type: "heal", value: 3, aoe: true}],
    rarity: :rare
  },

  # Druid Cards
  %{
    name: "Entangling Roots",
    headline: "Roots an enemy in place",
    ap: 2,
    effects: [%{type: "root", value: 2}, %{type: "damage", value: 2}],
    rarity: :uncommon
  },
  %{
    name: "Rejuvenation",
    headline: "Heals the target over time",
    ap: 1,
    effects: [%{type: "heal", value: 2}, %{type: "regen", value: 3}],
    rarity: :uncommon
  },
  %{
    name: "Wild Growth",
    headline: "Accelerates natural healing",
    ap: 2,
    effects: [%{type: "heal", value: 3}, %{type: "growth", value: 2}],
    rarity: :uncommon
  },
  %{
    name: "Moonfire",
    headline: "Burns the target with lunar energy",
    ap: 1,
    effects: [%{type: "damage", value: 3}, %{type: "burn", value: 2}],
    rarity: :common
  },

  # Sacrifice — a cursed card meant to be given to enemies via the give effect.
  # When played, it deals 2 damage to the caster then removes itself from the deck.
  %{
    name: "Sacrifice",
    headline: "A cursed gift that wounds its wielder and then vanishes",
    ap: 0,
    effects: [
      %{type: "damage", value: 2},
      %{type: "self_destruct"}
    ],
    targeting: %{"type" => "character"},
    rarity: :rare
  }
]

# Insert all base cards and create a map for easy lookup by name
cards_map =
  cards
  |> Enum.map(fn card -> Repo.insert!(%BaseCard{} |> BaseCard.changeset(card)) end)
  |> Enum.map(fn card -> {card.name, card} end)
  |> Enum.into(%{})

# Insert cards that reference other cards by ID (must come after cards_map is built)
sacrifice_id = cards_map["Sacrifice"].id

cursed_gift =
  Repo.insert!(
    %BaseCard{}
    |> BaseCard.changeset(%{
      name: "Cursed Gift",
      headline: "Give an enemy the Sacrifice card — a wound waiting to happen",
      ap: 1,
      effects: [%{type: "give", value: %{"card" => sacrifice_id, "pile" => "hand"}}],
      targeting: %{"type" => "character"},
      rarity: :rare
    })
  )

cards_map = Map.put(cards_map, "Cursed Gift", cursed_gift)

# Create base decks for each class
{:ok, warrior_deck} = Repo.insert(%BaseDeck{name: "Warrior Starter"})
{:ok, mage_deck} = Repo.insert(%BaseDeck{name: "Mage Starter"})
{:ok, ranger_deck} = Repo.insert(%BaseDeck{name: "Ranger Starter"})
{:ok, rogue_deck} = Repo.insert(%BaseDeck{name: "Rogue Starter"})
{:ok, cleric_deck} = Repo.insert(%BaseDeck{name: "Cleric Starter"})
{:ok, paladin_deck} = Repo.insert(%BaseDeck{name: "Paladin Starter"})
{:ok, druid_deck} = Repo.insert(%BaseDeck{name: "Druid Starter"})

# Associate cards with decks using the map
# Warrior Deck Cards (15 total)
[
  {"Strike", 4},
  {"Cleave", 3},
  {"Block", 4},
  {"Execute", 2},
  {"Whirlwind", 2}
]
|> Enum.each(fn {name, count} ->
  Repo.insert!(%BaseDeckCard{
    deck_id: warrior_deck.id,
    card_id: cards_map[name].id,
    count: count
  })
end)

# Mage Deck Cards (15 total)
[
  {"Fireball", 4},
  {"Icicle", 3},
  {"Lightning Bolt", 2},
  {"Arcane Explosion", 2},
  {"Mana Shield", 4}
]
|> Enum.each(fn {name, count} ->
  Repo.insert!(%BaseDeckCard{
    deck_id: mage_deck.id,
    card_id: cards_map[name].id,
    count: count
  })
end)

# Ranger Deck Cards (15 total)
[
  {"Shot", 5},
  {"Multishot", 3},
  {"Poison Arrow", 3},
  {"Snipe", 2},
  {"Evade", 2}
]
|> Enum.each(fn {name, count} ->
  Repo.insert!(%BaseDeckCard{
    deck_id: ranger_deck.id,
    card_id: cards_map[name].id,
    count: count
  })
end)

# Rogue Deck Cards (15 total)
[
  {"Strike", 3},
  {"Backstab", 4},
  {"Evade", 3},
  {"Shadowstrike", 2},
  {"Poison Dagger", 3}
]
|> Enum.each(fn {name, count} ->
  Repo.insert!(%BaseDeckCard{
    deck_id: rogue_deck.id,
    card_id: cards_map[name].id,
    count: count
  })
end)

# Cleric Deck Cards (15 total)
[
  {"Heal", 5},
  {"Strike", 2},
  {"Group Heal", 2},
  {"Purify", 3},
  {"Divine Shield", 3}
]
|> Enum.each(fn {name, count} ->
  Repo.insert!(%BaseDeckCard{
    deck_id: cleric_deck.id,
    card_id: cards_map[name].id,
    count: count
  })
end)

# Paladin Deck Cards (15 total)
[
  {"Strike", 3},
  {"Holy Strike", 3},
  {"Righteous Defense", 3},
  {"Consecration", 2},
  {"Heal", 2},
  {"Divine Shield", 2}
]
|> Enum.each(fn {name, count} ->
  Repo.insert!(%BaseDeckCard{
    deck_id: paladin_deck.id,
    card_id: cards_map[name].id,
    count: count
  })
end)

# Druid Deck Cards (15 total)
[
  {"Entangling Roots", 3},
  {"Rejuvenation", 3},
  {"Wild Growth", 3},
  {"Moonfire", 4},
  {"Heal", 2}
]
|> Enum.each(fn {name, count} ->
  Repo.insert!(%BaseDeckCard{
    deck_id: druid_deck.id,
    card_id: cards_map[name].id,
    count: count
  })
end)

# Create BaseClass records
alias Game.Content.BaseClass
alias Game.FormulaAliases.FormulaAlias

formula_aliases = [
  %{
    name: "self",
    description: "Target is the caster",
    expression: %{"===" => [%{"var" => "caster.id"}, %{"var" => "target.id"}]}
  },
  %{
    name: "not_self",
    description: "Target is not the caster",
    expression: %{"!" => [%{"===" => [%{"var" => "caster.id"}, %{"var" => "target.id"}]}]}
  },
  %{
    name: "ally",
    description: "Target is on the same team as the caster",
    expression: %{"===" => [%{"var" => "caster.team"}, %{"var" => "target.team"}]}
  },
  %{
    name: "enemy",
    description: "Target is on a different team from the caster",
    expression: %{"!==" => [%{"var" => "caster.team"}, %{"var" => "target.team"}]}
  },
  %{
    name: "target_alive",
    description: "Target has HP above zero",
    expression: %{">" => [%{"var" => "target.hp"}, 0]}
  },
  %{
    name: "target_enemy_alive",
    description: "Target is an enemy with HP above zero",
    expression: %{
      "and" => [
        %{"!==" => [%{"var" => "caster.team"}, %{"var" => "target.team"}]},
        %{">" => [%{"var" => "target.hp"}, 0]}
      ]
    }
  },
  %{
    name: "target_ally_alive",
    description: "Target is an ally with HP above zero",
    expression: %{
      "and" => [
        %{"===" => [%{"var" => "caster.team"}, %{"var" => "target.team"}]},
        %{">" => [%{"var" => "target.hp"}, 0]}
      ]
    }
  },
  %{
    name: "caster_missing_hp",
    description: "How much HP the caster is missing",
    expression: %{"-" => [%{"var" => "caster.max_hp"}, %{"var" => "caster.hp"}]}
  },
  %{
    name: "target_missing_hp",
    description: "How much HP the target is missing",
    expression: %{"-" => [%{"var" => "target.max_hp"}, %{"var" => "target.hp"}]}
  },
  %{
    name: "caster_hp_percent",
    description: "Caster current HP as a fraction of max",
    expression: %{"/" => [%{"var" => "caster.hp"}, %{"var" => "caster.max_hp"}]}
  },
  %{
    name: "target_hp_percent",
    description: "Target current HP as a fraction of max",
    expression: %{"/" => [%{"var" => "target.hp"}, %{"var" => "target.max_hp"}]}
  },
  %{
    name: "target_below_half",
    description: "Target HP is below 50%",
    expression: %{"<" => [%{"var" => "target.hp"}, %{"/" => [%{"var" => "target.max_hp"}, 2]}]}
  },
  %{
    name: "caster_is_hidden",
    description: "True if the caster currently has the stealth status effect",
    expression: %{
      "some" => [%{"var" => "caster.status_effects"}, %{"===" => [%{"var" => "type"}, "stealth"]}]
    }
  },
  %{
    name: "target_is_stealthed",
    description: "True if the target currently has the stealth status effect",
    expression: %{
      "some" => [%{"var" => "target.status_effects"}, %{"===" => [%{"var" => "type"}, "stealth"]}]
    }
  },
  %{
    name: "target_is_stuck",
    description: "True if the target currently has the stuck status effect",
    expression: %{
      "some" => [%{"var" => "target.status_effects"}, %{"===" => [%{"var" => "type"}, "stuck"]}]
    }
  },
  %{
    name: "target_is_stunned",
    description: "True if the target currently has the stun status effect",
    expression: %{
      "some" => [%{"var" => "target.status_effects"}, %{"===" => [%{"var" => "type"}, "stun"]}]
    }
  }
]

Enum.each(formula_aliases, fn attrs ->
  Repo.insert!(FormulaAlias.changeset(%FormulaAlias{}, attrs))
end)

Repo.insert!(%BaseClass{
  class: "fighter",
  base_hp: 20,
  base_ap: 3,
  base_movement: 2,
  deck_id: warrior_deck.id
})

Repo.insert!(%BaseClass{
  class: "mage",
  base_hp: 15,
  base_ap: 3,
  base_movement: 1,
  deck_id: mage_deck.id
})

Repo.insert!(%BaseClass{
  class: "ranger",
  base_hp: 18,
  base_ap: 3,
  base_movement: 2,
  deck_id: ranger_deck.id
})

Repo.insert!(%BaseClass{
  class: "rogue",
  base_hp: 16,
  base_ap: 4,
  base_movement: 3,
  deck_id: rogue_deck.id
})

Repo.insert!(%BaseClass{
  class: "cleric",
  base_hp: 17,
  base_ap: 3,
  base_movement: 1,
  deck_id: cleric_deck.id
})

Repo.insert!(%BaseClass{
  class: "paladin",
  base_hp: 22,
  base_ap: 2,
  base_movement: 1,
  deck_id: paladin_deck.id
})

Repo.insert!(%BaseClass{
  class: "druid",
  base_hp: 16,
  base_ap: 3,
  base_movement: 2,
  deck_id: druid_deck.id
})
