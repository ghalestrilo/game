defmodule Game.Card do
  defstruct [
    :id,
    :name,
    :description,
    # AP cost to play
    :cost,
    # Function reference or data structure representing effect
    :effects,
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

  @type card_effect() :: {:damage, integer()} | {:heal, integer()}

  @type t() :: %__MODULE__{
          id: integer(),
          name: String.t(),
          description: String.t(),
          cost: integer(),
          effects: list(card_effect())
        }
end
