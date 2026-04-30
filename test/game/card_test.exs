defmodule Game.CardTest do
  use Game.DataCase, async: true
  alias Game.{Card, Grid, CombatState, Character}
  alias Game.Combat.CardEffects.{Damage, Heal, Summon}

  describe "JsonLogic-based targeting" do
    test "get_targeting_type/1 returns :tile for summon cards" do
      card = %Card{
        id: 1,
        name: "Summon Wolf",
        effects: [%Summon{type: :summon, value: "wolf"}],
        cost: 2,
        targeting: %{
          "type" => "tile",
          "rule" => %{"!" => %{"var" => "target.occupied"}}
        }
      }

      assert Card.get_targeting_type(card) == :tile
    end

    test "get_targeting_type/1 returns :character for damage cards" do
      card = %Card{
        id: 1,
        name: "Attack",
        effects: [%Damage{type: :damage, value: 5}],
        cost: 1,
        targeting: %{
          "type" => "character",
          "rule" => %{"var" => "target.occupied"}
        }
      }

      assert Card.get_targeting_type(card) == :character
    end

    test "damage effect with character targeting validates character present" do
      card = %Card{
        id: 1,
        name: "Attack",
        effects: [%Damage{type: :damage, value: 5}],
        cost: 1,
        range: 5,
        targeting: %{
          "type" => "character",
          "rule" => %{"var" => "target.occupied"}
        }
      }

      grid = Grid.new({2, 2, 2})
      character = %Character{id: 1, position: {0, 0, 0}, name: "Enemy", team: :enemy}
      grid = Grid.update_character(grid, character)
      combat = %CombatState{grid: grid}

      {:ok, result} = Card.is_target_cell_valid?(card, {0, 0, 0}, combat)
      assert result.id == 1
    end

    test "summon effect with tile targeting validates empty tile" do
      card = %Card{
        id: 1,
        name: "Summon Wolf",
        effects: [%Summon{type: :summon, value: "wolf"}],
        cost: 2,
        targeting: %{
          "type" => "tile",
          "rule" => %{"!" => %{"var" => "target.occupied"}}
        }
      }

      grid = Grid.new({2, 2, 2})
      combat = %CombatState{grid: grid}

      assert Card.is_target_cell_valid?(card, {0, 0, 0}, combat) == {:ok, nil}
    end

    test "summon effect rejects occupied tile using JsonLogic" do
      card = %Card{
        id: 1,
        name: "Summon Wolf",
        effects: [%Summon{type: :summon, value: "wolf"}],
        cost: 2,
        targeting: %{
          "type" => "tile",
          "rule" => %{"!" => %{"var" => "target.occupied"}}
        }
      }

      grid = Grid.new({2, 2, 2})
      character = %Character{id: 1, position: {0, 0, 0}, name: "Blocking"}
      grid = Grid.update_character(grid, character)
      combat = %CombatState{grid: grid}

      assert Card.is_target_cell_valid?(card, {0, 0, 0}, combat) ==
               {:error, "Target does not match targeting rule"}
    end

    test "heal effect with ally-only targeting validates ally characters" do
      card = %Card{
        id: 1,
        name: "Heal Ally",
        effects: [%Heal{type: :heal, value: 10}],
        cost: 2,
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

      grid = Grid.new({2, 2, 2})
      ally = %Character{id: 1, position: {0, 0, 0}, name: "Ally", team: :ally}
      grid = Grid.update_character(grid, ally)
      current_player = %Character{id: 2, position: {1, 0, -1}, name: "Player", team: :ally}
      combat = %CombatState{grid: grid, current_turn: 0, queue: [current_player, ally]}

      {:ok, result} = Card.is_target_cell_valid?(card, {0, 0, 0}, combat)
      assert result.team == :ally
    end

    test "heal effect with ally-only targeting rejects enemy characters" do
      card = %Card{
        id: 1,
        name: "Heal Ally",
        effects: [%Heal{type: :heal, value: 10}],
        cost: 2,
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

      grid = Grid.new({2, 2, 2})
      enemy = %Character{id: 1, position: {0, 0, 0}, name: "Enemy", team: :enemy}
      grid = Grid.update_character(grid, enemy)
      combat = %CombatState{grid: grid}

      assert Card.is_target_cell_valid?(card, {0, 0, 0}, combat) ==
               {:error, "Target does not match targeting rule"}
    end

    test "damage effect with enemy-only targeting validates enemy characters" do
      card = %Card{
        id: 1,
        name: "Attack Enemy",
        effects: [%Damage{type: :damage, value: 5}],
        cost: 1,
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

      grid = Grid.new({2, 2, 2})
      enemy = %Character{id: 1, position: {0, 0, 0}, name: "Enemy", team: :enemy}
      grid = Grid.update_character(grid, enemy)
      combat = %CombatState{grid: grid}

      {:ok, result} = Card.is_target_cell_valid?(card, {0, 0, 0}, combat)
      assert result.team == :enemy
    end

    test "complex JsonLogic rule for wounded allies only" do
      card = %Card{
        id: 1,
        name: "Heal Wounded Ally",
        effects: [%Heal{type: :heal, value: 10}],
        cost: 2,
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

      grid = Grid.new({2, 2, 2})

      wounded_ally = %Character{
        id: 1,
        position: {0, 0, 0},
        name: "Wounded",
        team: :ally,
        hp: 5,
        max_hp: 10
      }

      grid = Grid.update_character(grid, wounded_ally)
      current_player = %Character{id: 2, position: {1, 0, -1}, name: "Player", team: :ally}
      combat = %CombatState{grid: grid, current_turn: 0, queue: [current_player, wounded_ally]}

      {:ok, result} = Card.is_target_cell_valid?(card, {0, 0, 0}, combat)
      assert result.hp == 5
    end

    test "complex JsonLogic rule rejects full health allies" do
      card = %Card{
        id: 1,
        name: "Heal Wounded Ally",
        effects: [%Heal{type: :heal, value: 10}],
        cost: 2,
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

      grid = Grid.new({2, 2, 2})

      healthy_ally = %Character{
        id: 1,
        position: {0, 0, 0},
        name: "Healthy",
        team: :ally,
        hp: 10,
        max_hp: 10
      }

      grid = Grid.update_character(grid, healthy_ally)
      current_player = %Character{id: 2, position: {1, 0, -1}, name: "Player", team: :ally}
      combat = %CombatState{grid: grid, current_turn: 0, queue: [current_player, healthy_ally]}

      assert Card.is_target_cell_valid?(card, {0, 0, 0}, combat) ==
               {:error, "Target does not match targeting rule"}
    end

    test "card targeting field determines targeting type regardless of effects" do
      card = %Card{
        id: 1,
        name: "Strike and Heal",
        effects: [
          %Damage{type: :damage, value: 5},
          %Heal{type: :heal, value: 2}
        ],
        cost: 3,
        targeting: %{
          "type" => "character",
          "rule" => %{"var" => "target.occupied"}
        }
      }

      assert Card.get_targeting_type(card) == :character
    end

    test "targeting rule can access game state variables using JsonLogic" do
      card = %Card{
        id: 1,
        name: "Enemy Strike",
        effects: [%Damage{type: :damage, value: 5}],
        cost: 1,
        targeting: %{
          "type" => "character",
          "rule" => %{
            "and" => [
              %{"var" => "target.occupied"},
              %{
                "!=" => [
                  %{"var" => "target.team"},
                  %{"var" => "state.combat.current_turn.player.team"}
                ]
              }
            ]
          }
        }
      }

      grid = Grid.new({2, 2, 2})
      enemy = %Character{id: 2, position: {0, 0, 0}, name: "Enemy", team: :enemy}
      grid = Grid.update_character(grid, enemy)

      player = %Character{id: 1, position: {1, 0, -1}, name: "Player", team: :ally}

      combat = %CombatState{
        grid: grid,
        current_turn: %{
          player: player,
          starting_position: {1, 0, -1},
          card: nil
        }
      }

      {:ok, result} = Card.is_target_cell_valid?(card, {0, 0, 0}, combat)
      assert result.team == :enemy
    end

    test "targeting rule rejects when game state condition fails" do
      card = %Card{
        id: 1,
        name: "Heavy Strike",
        effects: [%Damage{type: :damage, value: 10}],
        cost: 1,
        targeting: %{
          "type" => "character",
          "rule" => %{
            "and" => [
              %{"var" => "target.occupied"},
              %{
                ">=" => [
                  %{"var" => "state.combat.current_turn.player.ap"},
                  3
                ]
              }
            ]
          }
        }
      }

      grid = Grid.new({2, 2, 2})
      enemy = %Character{id: 2, position: {0, 0, 0}, name: "Enemy", team: :enemy}
      grid = Grid.update_character(grid, enemy)

      player = %Character{
        id: 1,
        position: {1, 0, -1},
        name: "Player",
        team: :ally,
        ap: 2,
        max_ap: 5
      }

      combat = %CombatState{
        grid: grid,
        current_turn: %{
          player: player,
          starting_position: {1, 0, -1},
          card: nil
        }
      }

      assert Card.is_target_cell_valid?(card, {0, 0, 0}, combat) ==
               {:error, "Target does not match targeting rule"}
    end
  end

  describe "procedural effect values" do
    test "process_card/3 resolves damage value from caster.hp expression" do
      caster = %Character{
        id: 1,
        name: "Caster",
        hp: 12,
        max_hp: 20,
        ap: 3,
        max_ap: 3,
        position: {0, 0, 0},
        team: :team1,
        cards: %{draw: [], hand: [], discard: []}
      }

      target = %Character{
        id: 2,
        name: "Target",
        hp: 20,
        max_hp: 20,
        ap: 3,
        max_ap: 3,
        position: {1, 0, -1},
        team: :team2,
        cards: %{draw: [], hand: [], discard: []}
      }

      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: caster},
          {1, 0, -1} => %{terrain: :plain, occupied_by: target}
        }
      }

      card = %Card{
        id: 1,
        name: "Vampiric Strike",
        cost: 1,
        effects: [%{"type" => "damage", "value" => %{"var" => "caster.hp"}}],
        targeting: %{"type" => "character"}
      }

      combat_state = %CombatState{
        state: :running,
        __constants__: %{players: [caster, target]},
        queue: [caster, target],
        grid: grid,
        current_turn: %{player: caster, starting_position: caster.position, card: nil}
      }

      {updated_state, _} = Card.process_card(combat_state, target, card)
      updated_target = Enum.find(updated_state.queue, &(&1.id == target.id))
      assert updated_target.hp == target.hp - caster.hp
    end
  end
end
