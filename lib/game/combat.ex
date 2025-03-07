defmodule Game.Character do
  defstruct [
    :id,
    :name,
    :class,
    # Action Points
    :ap,
    # Health Points
    :hp,
    # List of Cards
    :deck,
    # Hex grid position {q, r, s}
    :position,
    # List of active status effects
    :status_effects
  ]
end

defmodule Game.Card do
  defstruct [
    :id,
    :name,
    :description,
    # AP cost to play
    :cost,
    # Function reference or data structure representing effect
    :effect,
    # Range of effect in hex tiles
    :range,
    # Type of targeting (self, single, AoE, etc.)
    :targeting,
    # Rarity tier (Common, Uncommon, Rare, etc.)
    :rarity,
    # Elemental affinity (Fire, Ice, Lightning, etc.)
    :element,
    # Number of times the action is repeated
    :multi_strike,
    # List of additional effects triggered under certain conditions
    :conditional_effects,
    # Tags that interact with other cards in a deck
    :synergy_tags,
    # Number of rune slots available for further customization
    :rune_slots,
    # Scaling mechanics (e.g., increased power per use, missing HP bonus, etc.)
    :scaling
  ]
end

defmodule Game.Deck do
  defstruct [
    :id,
    # Owner of the deck
    :character_id,
    # List of card IDs
    :cards
  ]
end

defmodule Game.Grid do
  defstruct [
    # Map of {q, r, s} => tile info
    :tiles
  ]
end

defmodule Game.Tile do
  defstruct [
    # Type of terrain (plain, water, obstacle, etc.)
    :terrain,
    # Character ID if occupied
    :occupied_by
  ]
end

defmodule Game.Battle do
  defstruct [
    :id,
    # List of characters participating
    :characters,
    # Battle grid
    :grid
  ]
end

defmodule Game.StatusEffect do
  defstruct [
    :id,
    :name,
    :description,
    # How long the effect lasts
    :duration,
    # List of modifications to apply (damage multipliers, AP cost changes, etc.)
    :modifiers,
    # Function reference for removing the effect
    :removal_condition
  ]
end

defmodule Game.ClassSkills do
  def cleric_skills do
    [
      %Game.Card{
        id: 1,
        name: "Healing Word",
        description: "Heal an ally from range.",
        cost: 2,
        effect: :heal,
        range: 3,
        targeting: :single,
        rarity: :common,
        element: :holy
      },
      %Game.Card{
        id: 2,
        name: "Divine Smite",
        description: "Empower a melee attack with radiant damage.",
        cost: 3,
        effect: :bonus_radiant_damage,
        range: 1,
        targeting: :single,
        rarity: :uncommon,
        element: :radiant
      },
      %Game.Card{
        id: 3,
        name: "Shield of Faith",
        description: "Increase an ally's defense for a duration.",
        cost: 2,
        effect: :defense_boost,
        range: 2,
        targeting: :single,
        rarity: :common,
        element: :holy
      },
      %Game.Card{
        id: 4,
        name: "Cure Wounds",
        description: "Restore a large amount of HP to an ally.",
        cost: 3,
        effect: :large_heal,
        range: 1,
        targeting: :single,
        rarity: :uncommon,
        element: :holy
      },
      %Game.Card{
        id: 5,
        name: "Bless",
        description: "Increase allies' accuracy and damage.",
        cost: 2,
        effect: :buff_accuracy_damage,
        range: 2,
        targeting: :multi,
        rarity: :uncommon,
        element: :holy
      },
      %Game.Card{
        id: 6,
        name: "Holy Nova",
        description: "Deal radiant damage in an area and heal allies.",
        cost: 4,
        effect: :area_heal_and_damage,
        range: 2,
        targeting: :aoe,
        rarity: :rare,
        element: :radiant
      },
      %Game.Card{
        id: 7,
        name: "Revive",
        description: "Bring a fallen ally back to life.",
        cost: 5,
        effect: :revive,
        range: 1,
        targeting: :single,
        rarity: :legendary,
        element: :holy
      },
      %Game.Card{
        id: 8,
        name: "Turn Undead",
        description: "Force undead enemies to flee.",
        cost: 3,
        effect: :fear_undead,
        range: 3,
        targeting: :multi,
        rarity: :rare,
        element: :radiant
      },
      %Game.Card{
        id: 9,
        name: "Sanctuary",
        description: "Protect an ally from attacks until they act.",
        cost: 2,
        effect: :damage_negation,
        range: 2,
        targeting: :single,
        rarity: :uncommon,
        element: :holy
      },
      %Game.Card{
        id: 10,
        name: "Smite Evil",
        description: "Deal bonus damage to evil-aligned creatures.",
        cost: 3,
        effect: :bonus_damage_evil,
        range: 1,
        targeting: :single,
        rarity: :rare,
        element: :radiant
      }
    ]
  end

  def fighter_skills do
    [
      %Game.Card{
        id: 11,
        name: "Action Surge",
        description: "Gain an extra action this turn.",
        cost: 0,
        effect: :extra_action,
        range: 0,
        targeting: :self,
        rarity: :rare
      },
      %Game.Card{
        id: 12,
        name: "Second Wind",
        description: "Heal yourself for a small amount.",
        cost: 1,
        effect: :heal_self,
        range: 0,
        targeting: :self,
        rarity: :common
      },
      %Game.Card{
        id: 13,
        name: "Power Strike",
        description: "A powerful melee attack.",
        cost: 3,
        effect: :high_damage,
        range: 1,
        targeting: :single,
        rarity: :uncommon
      },
      %Game.Card{
        id: 14,
        name: "Parry",
        description: "Block an incoming attack.",
        cost: 2,
        effect: :damage_reduction,
        range: 0,
        targeting: :self,
        rarity: :common
      },
      %Game.Card{
        id: 15,
        name: "Riposte",
        description: "Counterattack when struck in melee.",
        cost: 2,
        effect: :counterattack,
        range: 1,
        targeting: :self,
        rarity: :uncommon
      },
      %Game.Card{
        id: 16,
        name: "Whirlwind Attack",
        description: "Strike all adjacent enemies.",
        cost: 4,
        effect: :aoe_melee,
        range: 1,
        targeting: :aoe,
        rarity: :rare
      }
    ]
  end
end
