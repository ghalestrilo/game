defmodule Game.Fixtures do
  alias Game.{Character, Card, Grid, Combat, CombatState}

  # Dynamic character creation
  def character(:warrior, id) do
    %Character{
      id: id,
      name: "Warrior",
      class: :fighter,
      ap: 3,
      hp: 20,
      position: {0, 0, 0},
      movement_range: 2,
      team: :team1,
      cards: %{
        draw: Enum.map(1..10, fn idx -> %{attack_card() | id: idx} end),
        hand: [],
        discard: []
      }
    }
  end

  def character(:mage, id) do
    %Character{
      id: id,
      name: "Mage",
      class: :mage,
      ap: 3,
      hp: 15,
      position: {2, 0, -2},
      movement_range: 1,
      team: :team2,
      cards: %{
        draw: Enum.map(1..10, fn idx -> %{fireball_card() | id: idx} end),
        hand: [],
        discard: []
      }
    }
  end

  def warrior do
    %Character{
      id: 1,
      name: "Warrior",
      class: :fighter,
      ap: 3,
      hp: 20,
      position: {0, 0, 0},
      movement_range: 2,
      team: :team1,
      cards: %{
        draw:
          [
            attack_card(),
            attack_card(),
            attack_card(),
            attack_card(),
            attack_card(),
            attack_card(),
            attack_card(),
            attack_card(),
            attack_card(),
            attack_card()
          ]
          |> Enum.with_index()
          |> Enum.map(fn {x, idx} -> %{x | id: idx} end),
        hand: [],
        discard: []
      }
    }
  end

  def mage do
    %Character{
      id: 2,
      name: "Mage",
      class: :mage,
      ap: 3,
      hp: 15,
      position: {2, 0, -2},
      movement_range: 1,
      team: :team2,
      cards: %{
        draw:
          [
            fireball_card(),
            fireball_card(),
            fireball_card(),
            heal_card(),
            heal_card(),
            heal_card(),
            heal_card(),
            heal_card(),
            fireball_card(),
            fireball_card()
          ]
          |> Enum.with_index()
          |> Enum.map(fn {x, idx} -> %{x | id: idx} end),
        hand: [],
        discard: []
      }
    }
  end

  def attack_card do
    %Card{
      id: 1,
      name: "Strike",
      cost: 1,
      effects: [%{"type" => "damage", "value" => 5}],
      range: 1
    }
  end

  def heal_card do
    %Card{
      id: 2,
      name: "Heal",
      cost: 2,
      effects: [%{"type" => "heal", "value" => 3}]
    }
  end

  def lethal_card do
    %Card{
      id: 4,
      name: "Death Strike",
      cost: 1,
      effects: [%{"type" => "damage", "value" => 20}]
    }
  end

  def basic_grid do
    %Grid{
      tiles: %{
        {0, 0, 0} => %{terrain: :plain, occupied_by: warrior()},
        {1, 0, -1} => %{terrain: :plain, occupied_by: nil},
        {2, 0, -2} => %{terrain: :plain, occupied_by: mage()},
        {3, 0, -3} => %{terrain: :plain, occupied_by: nil}
      }
    }
  end

  def basic_combat do
    warrior = warrior()
    mage = mage()

    %CombatState{
      state: :running,
      __constants__: %{
        players: [warrior, mage]
      },
      queue: [warrior, mage],
      grid: basic_grid(),
      current_turn: %{
        starting_position: warrior.position,
        player: warrior,
        card: nil
      }
    }
  end

  def warrior2 do
    %Character{
      id: 3,
      name: "Warrior 2",
      class: :fighter,
      ap: 3,
      hp: 20,
      position: {1, 0, -1},
      movement_range: 2,
      team: :team1,
      cards: %{
        draw: [attack_card(), attack_card(), attack_card()],
        hand: [attack_card(), attack_card()],
        discard: []
      }
    }
  end

  def expensive_card do
    %Card{
      id: 3,
      name: "Mega Strike",
      cost: 5,
      effects: [%{"type" => "damage", "value" => 10}]
    }
  end

  def self_harm_card do
    %Card{
      id: 5,
      name: "Self Harm",
      cost: 1,
      effects: [%{"type" => "damage", "value" => 5}]
    }
  end

  def max_heal_card do
    %Card{
      id: 7,
      name: "Max Heal",
      cost: 1,
      effects: [%{"type" => "heal", "value" => 100}]
    }
  end

  def negative_damage_card do
    %Card{
      id: 8,
      name: "Negative Strike",
      cost: 1,
      effects: [%{"type" => "damage", "value" => -5}]
    }
  end

  def fireball_card() do
    %Card{
      id: 9,
      name: "Fireball",
      cost: 1,
      effects: [%{"type" => "damage", "value" => 10}]
    }
  end

  def long_range_card() do
    %Card{
      id: 10,
      name: "Fireball",
      cost: 1,
      range: 3,
      effects: [%{"type" => "damage", "value" => 10}]
    }
  end
end
