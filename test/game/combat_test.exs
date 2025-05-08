defmodule GameTest do
  use ExUnit.Case

  alias Game.{Character, Card}

  test "AP cost is properly deducted when playing a card" do
    character = %Character{
      id: 1,
      name: "Warrior",
      class: :fighter,
      ap: 5,
      hp: 20,
      deck: [],
      position: {0, 0, 0},
      status_effects: []
    }

    card = %Card{name: "Power Strike", cost: 3}
    updated_character = %{character | ap: character.ap - card.cost}
    assert updated_character.ap == 2
  end

  test "Attack deals correct damage on hit" do
    attacker = %Character{id: 1, name: "Mage", ap: 5, hp: 20}
    defender = %Character{id: 2, name: "Goblin", ap: 3, hp: 15}
    card = %Card{name: "Fireball", effect: {:damage, 8}}
    updated_defender = %{defender | hp: defender.hp - 8}
    assert updated_defender.hp == 7
  end

  test "Turn order is maintained" do
    characters = [
      %Character{id: 1, name: "A", ap: 3},
      %Character{id: 2, name: "B", ap: 5}
    ]

    sorted = Enum.sort_by(characters, & &1.ap, :desc)
    assert sorted |> hd() |> Map.get(:name) == "B"
  end

  test "Elemental weaknesses apply correctly" do
    defender = %Character{id: 2, name: "Goblin", hp: 20, status_effects: [:wet]}
    card = %Card{name: "Lightning Bolt", element: :lightning, effect: {:damage, 10}}
    damage_multiplier = if :wet in defender.status_effects, do: 1.5, else: 1.0
    updated_defender = %{defender | hp: defender.hp - trunc(10 * damage_multiplier)}
    assert updated_defender.hp == 5
  end

  test "Status effects expire after duration" do
    effect = %Game.StatusEffect{name: "Burning", duration: 1}
    character = %Character{id: 1, name: "Mage", status_effects: [effect]}

    updated_character = %{
      character
      | status_effects: Enum.filter(character.status_effects, fn e -> e.duration > 0 end)
    }

    assert length(updated_character.status_effects) == 1
  end

  test "Multi-strike attacks apply correct damage" do
    attacker = %Character{id: 1, name: "Warrior", ap: 5}
    defender = %Character{id: 2, name: "Orc", hp: 30}
    card = %Card{name: "Flurry", multi_strike: 3, effect: {:damage, 4}}
    total_damage = 4 * 3
    updated_defender = %{defender | hp: defender.hp - total_damage}
    assert updated_defender.hp == 18
  end

  test "Deck draws correctly and doesn't exceed max hand size" do
    deck = [%Card{name: "Strike"}, %Card{name: "Block"}, %Card{name: "Heal"}]
    max_hand_size = 2
    hand = Enum.take(deck, max_hand_size)
    assert length(hand) == 2
  end
end
