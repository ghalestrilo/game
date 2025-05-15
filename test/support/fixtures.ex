defmodule Game.Fixtures do
  alias Game.{Character, Card, Grid, Combat}

  def warrior do
    %Character{
      id: 1,
      name: "Warrior",
      class: :fighter,
      ap: 3,
      hp: 20,
      position: {0, 0, 0},
      movement_range: 2,
      team: :team1
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
      team: :team2
    }
  end

  def attack_card do
    %Card{
      id: 1,
      name: "Strike",
      cost: 1,
      effect: {:damage, 5}
    }
  end

  def heal_card do
    %Card{
      id: 2,
      name: "Heal",
      cost: 2,
      effect: {:heal, 3}
    }
  end

  def lethal_card do
    %Card{
      id: 4,
      name: "Death Strike",
      cost: 1,
      effect: {:damage, 20}
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
    %Combat{
      state: :running,
      players: [warrior(), mage()],
      queue: [warrior(), mage()],
      grid: basic_grid(),
      current_turn: %{starting_position: warrior().position}
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
      team: :team1
    }
  end

  def expensive_card do
    %Card{
      id: 3,
      name: "Mega Strike",
      cost: 5,
      effect: {:damage, 10}
    }
  end

  def self_harm_card do
    %Card{
      id: 5,
      name: "Self Harm",
      cost: 1,
      effect: {:damage, 5}
    }
  end

  def max_heal_card do
    %Card{
      id: 7,
      name: "Max Heal",
      cost: 1,
      effect: {:heal, 100}
    }
  end

  def negative_damage_card do
    %Card{
      id: 8,
      name: "Negative Strike",
      cost: 1,
      effect: {:damage, -5}
    }
  end
end
