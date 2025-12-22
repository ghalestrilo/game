defmodule Game.CardTest do
  use Game.DataCase, async: true
  alias Game.{Card, Grid, CombatState}

  describe "get_targeting_type/1" do
    test "returns :tile for summon cards" do
      card = %Card{
        id: 1,
        name: "Summon Wolf",
        effects: [%{"type" => "summon", "value" => "wolf"}],
        cost: 1,
        range: 5
      }

      assert Card.get_targeting_type(card) == :tile
    end

    test "returns :character for damage cards" do
      card = %Card{
        id: 1,
        name: "Attack",
        effects: [%{"type" => "damage", "value" => 5}],
        cost: 1,
        range: 5
      }

      assert Card.get_targeting_type(card) == :character
    end

    test "returns :character when effects is nil" do
      card = %Card{
        id: 1,
        name: "Test",
        effects: nil,
        cost: 1,
        range: 5
      }

      assert Card.get_targeting_type(card) == :character
    end
  end

  describe "is_target_cell_valid?/3" do
    test "summon card validates empty tile" do
      card = %Card{
        id: 1,
        name: "Summon Wolf",
        effects: [%{"type" => "summon", "value" => "wolf"}],
        cost: 1,
        range: 5
      }

      grid = Grid.new({2, 2, 2})
      combat = %CombatState{grid: grid}

      # Empty tile should be valid
      assert Card.is_target_cell_valid?(card, {0, 0, 0}, combat) == {:ok, nil}
    end

    test "summon card rejects occupied tile" do
      card = %Card{
        id: 1,
        name: "Summon Wolf",
        effects: [%{"type" => "summon", "value" => "wolf"}],
        cost: 1,
        range: 5
      }

      grid = Grid.new({2, 2, 2})
      character = %Game.Character{id: 1, position: {0, 0, 0}, name: "Test"}
      grid = Grid.update_character(grid, character)
      combat = %CombatState{grid: grid}

      # Occupied tile should be invalid
      assert Card.is_target_cell_valid?(card, {0, 0, 0}, combat) == {:error, "Tile must be empty"}
    end

    test "damage card validates character at position" do
      card = %Card{
        id: 1,
        name: "Attack",
        effects: [%{"type" => "damage", "value" => 5}],
        cost: 1,
        range: 5
      }

      grid = Grid.new({2, 2, 2})
      character = %Game.Character{id: 1, position: {0, 0, 0}, name: "Test"}
      grid = Grid.update_character(grid, character)
      combat = %CombatState{grid: grid}

      # Character at position should be valid
      {:ok, result} = Card.is_target_cell_valid?(card, {0, 0, 0}, combat)
      assert result.id == 1
      assert result.name == "Test"
    end

    test "damage card rejects empty tile" do
      card = %Card{
        id: 1,
        name: "Attack",
        effects: [%{"type" => "damage", "value" => 5}],
        cost: 1,
        range: 5
      }

      grid = Grid.new({2, 2, 2})
      combat = %CombatState{grid: grid}

      # Empty tile should be invalid for damage card
      assert Card.is_target_cell_valid?(card, {0, 0, 0}, combat) == {:error, "No character at this position"}
    end
  end
end
