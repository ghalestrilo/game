# Game

To start your Phoenix server:

- Run `mix setup` to install and setup dependencies
- Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

- Official website: https://www.phoenixframework.org/
- Guides: https://hexdocs.pm/phoenix/overview.html
- Docs: https://hexdocs.pm/phoenix
- Forum: https://elixirforum.com/c/phoenix-forum
- Source: https://github.com/phoenixframework/phoenix

## Design

> An open-world couch coop simultaneous roguelike deckbuilding tactical MMORPG with card-based combat

- 1+ players group and explore the world together
- Each player creates a character or picks from a previously created one
- Each character has a deck of cards. This deck is what defines all their abilities in combat
- Combat happens in team turns, each turn all characters in the team are free to move and act in tandem

### Considerations

- There could be a time element to combat which a hexing/debuffing character could exploit
- Slay-the-spire/diceomancer style gameplay

### Data Model

- coordinate: {x,y,z} (hex tiles because hexagons are the bestagons)

```elixir
defmodule Game.Character do
  defstruct [
    :id,
    :name,
    :class,
    :ap,      # Action Points
    :hp,      # Health Points
    :deck,    # List of Cards
    :position, # Hex grid position {q, r, s}
    :status_effects # List of active status effects
  ]
end

defmodule Game.Card do
  defstruct [
    :id,
    :name,
    :description,
    :cost,       # AP cost to play
    :effect,     # Function reference or data structure representing effect
    :range,      # Range of effect in hex tiles
    :targeting,   # Type of targeting (self, single, AoE, etc.)
    :rarity,      # Rarity tier (Common, Uncommon, Rare, etc.)
    :element,     # Elemental affinity (Fire, Ice, Lightning, etc.)
    :multi_strike, # Number of times the action is repeated
    :conditional_effects, # List of additional effects triggered under certain conditions
    :synergy_tags, # Tags that interact with other cards in a deck
    :rune_slots,   # Number of rune slots available for further customization
    :scaling       # Scaling mechanics (e.g., increased power per use, missing HP bonus, etc.)
  ]
end

defmodule Game.Deck do
  defstruct [
    :id,
    :character_id, # Owner of the deck
    :cards         # List of card IDs
  ]
end

defmodule Game.Grid do
  defstruct [
    :tiles # Map of {q, r, s} => tile info
  ]
end

defmodule Game.Tile do
  defstruct [
    :terrain,   # Type of terrain (plain, water, obstacle, etc.)
    :occupied_by # Character ID if occupied
  ]
end

defmodule Game.Battle do
  defstruct [
    :id,
    :characters, # List of characters participating
    :grid        # Battle grid
  ]
end

defmodule Game.StatusEffect do
  defstruct [
    :id,
    :name,
    :description,
    :duration,     # How long the effect lasts
    :modifiers,    # List of modifications to apply (damage multipliers, AP cost changes, etc.)
    :removal_condition # Function reference for removing the effect
  ]
end



defmodule Game.ClassSkills do
  def cleric_skills do
    [
      %Game.Card{id: 1, name: "Healing Word", description: "Heal an ally from range.", cost: 2, effect: :heal, range: 3, targeting: :single, rarity: :common, element: :holy},
      %Game.Card{id: 2, name: "Divine Smite", description: "Empower a melee attack with radiant damage.", cost: 3, effect: :bonus_radiant_damage, range: 1, targeting: :single, rarity: :uncommon, element: :radiant},
      %Game.Card{id: 3, name: "Shield of Faith", description: "Increase an ally's defense for a duration.", cost: 2, effect: :defense_boost, range: 2, targeting: :single, rarity: :common, element: :holy},
      %Game.Card{id: 4, name: "Cure Wounds", description: "Restore a large amount of HP to an ally.", cost: 3, effect: :large_heal, range: 1, targeting: :single, rarity: :uncommon, element: :holy},
      %Game.Card{id: 5, name: "Bless", description: "Increase allies' accuracy and damage.", cost: 2, effect: :buff_accuracy_damage, range: 2, targeting: :multi, rarity: :uncommon, element: :holy},
      %Game.Card{id: 6, name: "Holy Nova", description: "Deal radiant damage in an area and heal allies.", cost: 4, effect: :area_heal_and_damage, range: 2, targeting: :aoe, rarity: :rare, element: :radiant},
      %Game.Card{id: 7, name: "Revive", description: "Bring a fallen ally back to life.", cost: 5, effect: :revive, range: 1, targeting: :single, rarity: :legendary, element: :holy},
      %Game.Card{id: 8, name: "Turn Undead", description: "Force undead enemies to flee.", cost: 3, effect: :fear_undead, range: 3, targeting: :multi, rarity: :rare, element: :radiant},
      %Game.Card{id: 9, name: "Sanctuary", description: "Protect an ally from attacks until they act.", cost: 2, effect: :damage_negation, range: 2, targeting: :single, rarity: :uncommon, element: :holy},
      %Game.Card{id: 10, name: "Smite Evil", description: "Deal bonus damage to evil-aligned creatures.", cost: 3, effect: :bonus_damage_evil, range: 1, targeting: :single, rarity: :rare, element: :radiant}
    ]
  end

  def fighter_skills do
    [
      %Game.Card{id: 11, name: "Action Surge", description: "Gain an extra action this turn.", cost: 0, effect: :extra_action, range: 0, targeting: :self, rarity: :rare},
      %Game.Card{id: 12, name: "Second Wind", description: "Heal yourself for a small amount.", cost: 1, effect: :heal_self, range: 0, targeting: :self, rarity: :common},
      %Game.Card{id: 13, name: "Power Strike", description: "A powerful melee attack.", cost: 3, effect: :high_damage, range: 1, targeting: :single, rarity: :uncommon},
      %Game.Card{id: 14, name: "Parry", description: "Block an incoming attack.", cost: 2, effect: :damage_reduction, range: 0, targeting: :self, rarity: :common},
      %Game.Card{id: 15, name: "Riposte", description: "Counterattack when struck in melee.", cost: 2, effect: :counterattack, range: 1, targeting: :self, rarity: :uncommon},
      %Game.Card{id: 16, name: "Whirlwind Attack", description: "Strike all adjacent enemies.", cost: 4, effect: :aoe_melee, range: 1, targeting: :aoe, rarity: :rare}
    ]
  end
end
```

### Class mechanics

**Rogue**

- Start with lvl 1 Stealth and Attack cards
  - Stealth: Become invisible until next round. At beginning of next round, scry 3 (then shuffle back):
    - if there's a stealth card, you may cast it for 0 ap cost
    - if there's an attack card, you may cast it for double damage
    - leveling up increases scry
  - Gets many reaction cards - eg. on targeted, attacked or discard events

**Monk**

- Many cards with cycling/scry
- Start with lvl 1 Flurry of blows and Attack cards
  - Flurry of blows: attack w/ effect - scry 3 (then shuffle back):
    - if there's an attack card, you may cast it for double damage
    - leveling up increases scry

**Sorcerer**

- Access to metamagic booster packs

**Mage**

- Many cards with scry
- Many cards with keep - can returns this card to hand once it's been played

**Fighter**

- Some options here
  - +1 hand size
  - +1 AP

**Druid**

-

## References and resourcess

https://elixirforum.com/t/is-liveview-a-suitable-choice-for-serving-as-a-game-server-for-a-simple-three-js-game/58155/6
https://github.com/5e-bits/5e-database
https://davehardee.com/QRSCoords/
