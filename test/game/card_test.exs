defmodule Game.CardTest do
  use Game.DataCase, async: true
  alias Game.{Card, Grid, CombatState, Character}
  alias Game.Combat.CardEffects.{Damage, Heal, Summon}

  describe "JsonLogic-based targeting" do
    test "get_targeting_type/1 returns :tile for summon cards" do
      summon_effect = %Summon{
        type: :summon,
        value: "wolf",
        targeting: %{
          "type" => "tile",
          "rule" => %{"!" => %{"var" => "target.occupied"}}
        }
      }

      card = %Card{
        id: 1,
        name: "Summon Wolf",
        effects: [summon_effect],
        cost: 2
      }

      assert Card.get_targeting_type(card) == :tile
    end

    test "get_targeting_type/1 returns :character for damage cards" do
      damage_effect = %Damage{
        type: :damage,
        value: 5,
        targeting: %{
          "type" => "character",
          "rule" => %{"var" => "target.occupied"}
        }
      }

      card = %Card{
        id: 1,
        name: "Attack",
        effects: [damage_effect],
        cost: 1
      }

      assert Card.get_targeting_type(card) == :character
    end

    test "damage effect with character targeting validates character present" do
      damage_effect = %Damage{
        type: :damage,
        value: 5,
        targeting: %{
          "type" => "character",
          "rule" => %{"var" => "target.occupied"}
        }
      }

      card = %Card{
        id: 1,
        name: "Attack",
        effects: [damage_effect],
        cost: 1,
        range: 5
      }

      grid = Grid.new({2, 2, 2})
      character = %Character{id: 1, position: {0, 0, 0}, name: "Enemy", team: :enemy}
      grid = Grid.update_character(grid, character)
      combat = %CombatState{grid: grid}

      {:ok, result} = Card.is_target_cell_valid?(card, {0, 0, 0}, combat)
      assert result.id == 1
    end

    test "summon effect with tile targeting validates empty tile" do
      summon_effect = %Summon{
        type: :summon,
        value: "wolf",
        targeting: %{
          "type" => "tile",
          "rule" => %{"!" => %{"var" => "target.occupied"}}
        }
      }

      card = %Card{
        id: 1,
        name: "Summon Wolf",
        effects: [summon_effect],
        cost: 2
      }

      grid = Grid.new({2, 2, 2})
      combat = %CombatState{grid: grid}

      assert Card.is_target_cell_valid?(card, {0, 0, 0}, combat) == {:ok, nil}
    end

    test "summon effect rejects occupied tile using JsonLogic" do
      summon_effect = %Summon{
        type: :summon,
        value: "wolf",
        targeting: %{
          "type" => "tile",
          "rule" => %{"!" => %{"var" => "target.occupied"}}
        }
      }

      card = %Card{
        id: 1,
        name: "Summon Wolf",
        effects: [summon_effect],
        cost: 2
      }

      grid = Grid.new({2, 2, 2})
      character = %Character{id: 1, position: {0, 0, 0}, name: "Blocking"}
      grid = Grid.update_character(grid, character)
      combat = %CombatState{grid: grid}

      assert Card.is_target_cell_valid?(card, {0, 0, 0}, combat) == {:error, "Target does not match targeting rule"}
    end

    test "heal effect with ally-only targeting validates ally characters" do
      heal_effect = %Heal{
        type: :heal,
        value: 10,
        targeting: %{
          "type" => "character",
          "rule" => %{
            "and" => [
              %{"var" => "target.occupied"},
              %{"==" => [%{"var" => "target.team"}, "ally"]}
            ]
          }
        }
      }

      card = %Card{
        id: 1,
        name: "Heal Ally",
        effects: [heal_effect],
        cost: 2
      }

      grid = Grid.new({2, 2, 2})
      ally = %Character{id: 1, position: {0, 0, 0}, name: "Ally", team: :ally}
      grid = Grid.update_character(grid, ally)
      current_player = %Character{id: 2, position: {1, 0, -1}, name: "Player", team: :ally}
      combat = %CombatState{grid: grid, current_turn: 0, queue: [current_player, ally]}

      {:ok, result} = Card.is_target_cell_valid?(card, {0, 0, 0}, combat)
      assert result.team == :ally
    end

    test "heal effect with ally-only targeting rejects enemy characters" do
      heal_effect = %Heal{
        type: :heal,
        value: 10,
        targeting: %{
          "type" => "character",
          "rule" => %{
            "and" => [
              %{"var" => "target.occupied"},
              %{"==" => [%{"var" => "target.team"}, "ally"]}
            ]
          }
        }
      }

      card = %Card{
        id: 1,
        name: "Heal Ally",
        effects: [heal_effect],
        cost: 2
      }

      grid = Grid.new({2, 2, 2})
      enemy = %Character{id: 1, position: {0, 0, 0}, name: "Enemy", team: :enemy}
      grid = Grid.update_character(grid, enemy)
      combat = %CombatState{grid: grid}

      assert Card.is_target_cell_valid?(card, {0, 0, 0}, combat) == {:error, "Target does not match targeting rule"}
    end

    test "damage effect with enemy-only targeting validates enemy characters" do
      damage_effect = %Damage{
        type: :damage,
        value: 5,
        targeting: %{
          "type" => "character",
          "rule" => %{
            "and" => [
              %{"var" => "target.occupied"},
              %{"==" => [%{"var" => "target.team"}, "enemy"]}
            ]
          }
        }
      }

      card = %Card{
        id: 1,
        name: "Attack Enemy",
        effects: [damage_effect],
        cost: 1
      }

      grid = Grid.new({2, 2, 2})
      enemy = %Character{id: 1, position: {0, 0, 0}, name: "Enemy", team: :enemy}
      grid = Grid.update_character(grid, enemy)
      combat = %CombatState{grid: grid}

      {:ok, result} = Card.is_target_cell_valid?(card, {0, 0, 0}, combat)
      assert result.team == :enemy
    end

    test "complex JsonLogic rule for wounded allies only" do
      heal_effect = %Heal{
        type: :heal,
        value: 10,
        targeting: %{
          "type" => "character",
          "rule" => %{
            "and" => [
              %{"var" => "target.occupied"},
              %{"==" => [%{"var" => "target.team"}, "ally"]},
              %{"<" => [%{"var" => "target.hp"}, %{"var" => "target.max_hp"}]}
            ]
          }
        }
      }

      card = %Card{
        id: 1,
        name: "Heal Wounded Ally",
        effects: [heal_effect],
        cost: 2
      }

      grid = Grid.new({2, 2, 2})

      # Wounded ally should be valid
      wounded_ally = %Character{id: 1, position: {0, 0, 0}, name: "Wounded", team: :ally, hp: 5, max_hp: 10}
      grid = Grid.update_character(grid, wounded_ally)
      current_player = %Character{id: 2, position: {1, 0, -1}, name: "Player", team: :ally}
      combat = %CombatState{grid: grid, current_turn: 0, queue: [current_player, wounded_ally]}

      {:ok, result} = Card.is_target_cell_valid?(card, {0, 0, 0}, combat)
      assert result.hp == 5
    end

    test "complex JsonLogic rule rejects full health allies" do
      heal_effect = %Heal{
        type: :heal,
        value: 10,
        targeting: %{
          "type" => "character",
          "rule" => %{
            "and" => [
              %{"var" => "target.occupied"},
              %{"==" => [%{"var" => "target.team"}, "ally"]},
              %{"<" => [%{"var" => "target.hp"}, %{"var" => "target.max_hp"}]}
            ]
          }
        }
      }

      card = %Card{
        id: 1,
        name: "Heal Wounded Ally",
        effects: [heal_effect],
        cost: 2
      }

      grid = Grid.new({2, 2, 2})

      # Full health ally should be invalid
      healthy_ally = %Character{id: 1, position: {0, 0, 0}, name: "Healthy", team: :ally, hp: 10, max_hp: 10}
      grid = Grid.update_character(grid, healthy_ally)
      current_player = %Character{id: 2, position: {1, 0, -1}, name: "Player", team: :ally}
      combat = %CombatState{grid: grid, current_turn: 0, queue: [current_player, healthy_ally]}

      assert Card.is_target_cell_valid?(card, {0, 0, 0}, combat) == {:error, "Target does not match targeting rule"}
    end

    test "card with multiple effects uses first effect's targeting type" do
      damage_effect = %Damage{
        type: :damage,
        value: 5,
        targeting: %{
          "type" => "character",
          "rule" => %{"var" => "target.occupied"}
        }
      }

      # Second effect doesn't affect targeting determination
      heal_effect = %Heal{
        type: :heal,
        value: 2,
        targeting: nil
      }

      card = %Card{
        id: 1,
        name: "Strike and Heal",
        effects: [damage_effect, heal_effect],
        cost: 3
      }

      assert Card.get_targeting_type(card) == :character
    end

    test "targeting rule can access game state variables using JsonLogic" do
      # Create a damage effect that only targets enemies and checks current player's team
      damage_effect = %Damage{
        type: :damage,
        value: 5,
        targeting: %{
          "type" => "character",
          "rule" => %{
            "and" => [
              %{"var" => "target.occupied"},
              # Target must be on a different team than current player
              %{"!=" => [
                %{"var" => "target.team"},
                %{"var" => "state.combat.current_turn.player.team"}
              ]}
            ]
          }
        }
      }

      card = %Card{
        id: 1,
        name: "Enemy Strike",
        effects: [damage_effect],
        cost: 1
      }

      # Setup grid with enemy
      grid = Grid.new({2, 2, 2})
      enemy = %Character{id: 2, position: {0, 0, 0}, name: "Enemy", team: :enemy}
      grid = Grid.update_character(grid, enemy)

      # Setup current player
      player = %Character{id: 1, position: {1, 0, -1}, name: "Player", team: :ally}

      combat = %CombatState{
        grid: grid,
        current_turn: %{
          player: player,
          starting_position: {1, 0, -1},
          card: nil
        }
      }

      # Should be valid - enemy has different team than current player
      {:ok, result} = Card.is_target_cell_valid?(card, {0, 0, 0}, combat)
      assert result.team == :enemy
    end

    test "targeting rule rejects when game state condition fails" do
      # Create a damage effect that only works if current player has enough AP
      damage_effect = %Damage{
        type: :damage,
        value: 10,
        targeting: %{
          "type" => "character",
          "rule" => %{
            "and" => [
              %{"var" => "target.occupied"},
              # Current player must have at least 3 AP
              %{">=" => [
                %{"var" => "state.combat.current_turn.player.ap"},
                3
              ]}
            ]
          }
        }
      }

      card = %Card{
        id: 1,
        name: "Heavy Strike",
        effects: [damage_effect],
        cost: 1
      }

      # Setup grid with enemy
      grid = Grid.new({2, 2, 2})
      enemy = %Character{id: 2, position: {0, 0, 0}, name: "Enemy", team: :enemy}
      grid = Grid.update_character(grid, enemy)

      # Setup current player with insufficient AP
      player = %Character{id: 1, position: {1, 0, -1}, name: "Player", team: :ally, ap: 2, max_ap: 5}

      combat = %CombatState{
        grid: grid,
        current_turn: %{
          player: player,
          starting_position: {1, 0, -1},
          card: nil
        }
      }

      # Should be invalid - player doesn't have enough AP
      assert Card.is_target_cell_valid?(card, {0, 0, 0}, combat) ==
             {:error, "Target does not match targeting rule"}
    end
  end
end
