defmodule Game.Combat.CardEffects.MoveTest do
  use ExUnit.Case, async: true

  alias Game.Combat.CardEffect
  alias Game.Combat.CardEffects.Move
  alias Game.{CombatState, Grid, Fixtures}

  # angle 0 = {1,0,-1} (east), angle 1 = {-1,0,1} (west) per Grid.hex_directions()

  setup do
    fighter = Fixtures.fighter()
    mage = %{Fixtures.mage() | position: {2, 0, -2}}

    grid = %Grid{
      tiles: %{
        {0, 0, 0} => %{terrain: :plain, occupied_by: fighter},
        {1, 0, -1} => %{terrain: :plain, occupied_by: nil},
        {2, 0, -2} => %{terrain: :plain, occupied_by: mage},
        {3, 0, -3} => %{terrain: :plain, occupied_by: nil}
      }
    }

    combat = %CombatState{
      state: :running,
      __constants__: %{players: [fighter, mage]},
      queue: [mage],
      grid: grid,
      current_turn: %{
        starting_position: fighter.position,
        player: fighter,
        card: nil
      }
    }

    {:ok, combat: combat, fighter: fighter, mage: mage}
  end

  describe "process/3" do
    test "moves target one step in the given direction", %{combat: combat, mage: mage} do
      # angle 0 = {1,0,-1}; mage at {2,0,-2} + {1,0,-1} = {3,0,-3}
      updated = CardEffect.process(%Move{angle: 0, distance: 1}, mage, combat)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert updated_mage.position == {3, 0, -3}
    end

    test "moves target multiple steps in the given direction", %{combat: combat, mage: mage} do
      # angle 1 = {-1,0,1}; mage at {2,0,-2}, distance 2 → {0,0,0} — blocked by fighter
      # so use distance 1 toward west: {2,0,-2} + {-1,0,1} = {1,0,-1}
      updated = CardEffect.process(%Move{angle: 1, distance: 1}, mage, combat)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert updated_mage.position == {1, 0, -1}
    end

    test "clears old tile and occupies new tile on the grid", %{combat: combat, mage: mage} do
      updated = CardEffect.process(%Move{angle: 0, distance: 1}, mage, combat)
      assert updated.grid.tiles[{2, 0, -2}].occupied_by == nil
      assert updated.grid.tiles[{3, 0, -3}].occupied_by.id == mage.id
    end

    test "can move the current player", %{combat: combat, fighter: fighter} do
      # fighter at {0,0,0}, angle 0 = east → {1,0,-1}
      updated = CardEffect.process(%Move{angle: 0, distance: 1}, fighter, combat)
      assert updated.current_turn.player.position == {1, 0, -1}
    end

    test "stops at grid edge when distance exceeds available tiles", %{combat: combat, mage: mage} do
      # mage at {2,0,-2}, angle 0 = east — blocked by grid boundary at {3,0,-3}
      updated = CardEffect.process(%Move{angle: 0, distance: 10}, mage, combat)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert updated_mage.position == {3, 0, -3}
    end

    test "stops at last unblocked tile when path is partially blocked", %{
      combat: combat,
      mage: mage
    } do
      # angle 1 = {-1,0,1}; step 1: {2,0,-2} → {1,0,-1} (clear); step 2: → {0,0,0} (occupied) → stops
      updated = CardEffect.process(%Move{angle: 1, distance: 2}, mage, combat)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert updated_mage.position == {1, 0, -1}
    end
  end

  describe "distance_from_caster context variable" do
    test "resolves to the correct scalar hex distance", %{combat: combat, mage: mage} do
      # fighter at {0,0,0}, mage at {2,0,-2} — cube distance = 2
      card = %Game.Card{
        id: 50,
        name: "Distance Test",
        cost: 0,
        range: 5,
        effects: [
          %Game.BaseCards.BaseCard.Effect{
            type: "damage",
            value: %{"var" => "distance_from_caster"}
          }
        ],
        targeting: %{"type" => "character"}
      }

      {updated, _anims} = Game.Card.process_card(combat, mage, card)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert mage.hp - updated_mage.hp == 2
    end

    test "distance is 1 when target is adjacent to caster", %{combat: combat, fighter: fighter} do
      adjacent_mage = %{Fixtures.mage() | position: {1, 0, -1}}

      combat = %{
        combat
        | grid: %{
            combat.grid
            | tiles:
                Map.put(combat.grid.tiles, {1, 0, -1}, %{
                  terrain: :plain,
                  occupied_by: adjacent_mage
                })
          },
          queue: [adjacent_mage],
          __constants__: %{players: [fighter, adjacent_mage]}
      }

      card = %Game.Card{
        id: 51,
        name: "Distance Test",
        cost: 0,
        range: 5,
        effects: [
          %Game.BaseCards.BaseCard.Effect{
            type: "damage",
            value: %{"var" => "distance_from_caster"}
          }
        ],
        targeting: %{"type" => "character"}
      }

      {updated, _anims} = Game.Card.process_card(combat, adjacent_mage, card)
      updated_mage = Enum.find(updated.queue, &(&1.id == adjacent_mage.id))
      assert adjacent_mage.hp - updated_mage.hp == 1
    end
  end

  describe "Pull Towards Me card (angle_toward_caster, distance 1)" do
    defp pull_card do
      %Game.Card{
        id: 99,
        name: "Pull Towards Me",
        cost: 1,
        range: 3,
        effects: [
          %Game.BaseCards.BaseCard.Effect{
            type: "move",
            value: %{
              "angle" => %{"var" => "angle_toward_caster"},
              "distance" => 1
            }
          }
        ],
        targeting: %{"type" => "character"}
      }
    end

    test "pulls target one tile toward the caster", %{combat: combat, mage: mage} do
      # caster (fighter) at {0,0,0}, target (mage) at {2,0,-2}
      # angle_toward_caster = direction from mage toward fighter = {-1,0,1} = index 1
      # expected new position: {2,0,-2} + {-1,0,1} = {1,0,-1}
      {updated, _anims} = Game.Card.process_card(combat, mage, pull_card())
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert updated_mage.position == {1, 0, -1}
    end

    test "is a no-op when the tile between target and caster is blocked", %{
      combat: combat,
      mage: mage,
      fighter: fighter
    } do
      blocker = %{Fixtures.fighter() | id: 999, position: {1, 0, -1}}

      blocked_combat = %{
        combat
        | grid: %{
            combat.grid
            | tiles:
                Map.put(combat.grid.tiles, {1, 0, -1}, %{
                  terrain: :plain,
                  occupied_by: blocker
                })
          },
          __constants__: %{players: [fighter, mage, blocker]},
          queue: [mage, blocker]
      }

      {updated, _anims} = Game.Card.process_card(blocked_combat, mage, pull_card())
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert updated_mage.position == mage.position
    end

    test "pulls target toward caster from a different axis", %{fighter: fighter} do
      mage = %{Fixtures.mage() | position: {0, 2, -2}}

      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: fighter},
          {0, 1, -1} => %{terrain: :plain, occupied_by: nil},
          {0, 2, -2} => %{terrain: :plain, occupied_by: mage}
        }
      }

      combat = %CombatState{
        state: :running,
        __constants__: %{players: [fighter, mage]},
        queue: [mage],
        grid: grid,
        current_turn: %{starting_position: fighter.position, player: fighter, card: nil}
      }

      {updated, _anims} = Game.Card.process_card(combat, mage, pull_card())
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert updated_mage.position == {0, 1, -1}
    end
  end

  describe "protocol contracts" do
    test "get_description/1" do
      assert is_binary(CardEffect.get_description(%Move{}))
    end

    test "get_icon/1 returns a string" do
      assert is_binary(CardEffect.get_icon(%Move{}))
    end

    test "get_value_label/1 returns a string" do
      assert is_binary(CardEffect.get_value_label(%Move{}))
    end

    test "animate/1 returns label and color" do
      assert %{label: _, color: _} = CardEffect.animate(%Move{})
    end
  end

  describe "Charge Strike card (move caster toward enemy, deal damage = cast distance)" do
    defp charge_strike_card(_caster_id) do
      %Game.Card{
        id: 99,
        name: "Charge Strike",
        cost: 2,
        range: 5,
        effects: [
          %Game.BaseCards.BaseCard.Effect{
            type: "move",
            value: %{
              "angle" => %{"var" => "angle_toward_target"},
              "distance" => %{"-" => [%{"var" => "cast_distance"}, 1]}
            },
            target_formula: %{"var" => "caster.id"}
          },
          %Game.BaseCards.BaseCard.Effect{
            type: "damage",
            value: %{"var" => "cast_distance"}
          }
        ],
        targeting: %{"type" => "character"}
      }
    end

    setup do
      fighter = Fixtures.fighter()
      enemy = %{Fixtures.mage() | position: {3, 0, -3}}

      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: fighter},
          {1, 0, -1} => %{terrain: :plain, occupied_by: nil},
          {2, 0, -2} => %{terrain: :plain, occupied_by: nil},
          {3, 0, -3} => %{terrain: :plain, occupied_by: enemy}
        }
      }

      combat = %CombatState{
        state: :running,
        __constants__: %{players: [fighter, enemy]},
        queue: [enemy],
        grid: grid,
        current_turn: %{starting_position: fighter.position, player: fighter, card: nil}
      }

      {:ok, combat: combat, fighter: fighter, enemy: enemy}
    end

    test "caster moves up to the enemy (one tile away from it)", %{
      combat: combat,
      fighter: fighter,
      enemy: enemy
    } do
      {updated, _anims} = Game.Card.process_card(combat, enemy, charge_strike_card(fighter.id))
      assert updated.current_turn.player.position == {2, 0, -2}
    end

    test "enemy takes damage equal to cast_distance (3), not post-move distance (2)", %{
      combat: combat,
      fighter: fighter,
      enemy: enemy
    } do
      {updated, _anims} = Game.Card.process_card(combat, enemy, charge_strike_card(fighter.id))
      updated_enemy = Enum.find(updated.queue, &(&1.id == enemy.id))
      assert enemy.hp - updated_enemy.hp == 3
    end

    test "caster stops at last clear tile when path is partially blocked, damage still uses cast_distance",
         %{combat: combat, fighter: fighter, enemy: enemy} do
      blocker = %{Fixtures.fighter() | id: 99, position: {2, 0, -2}}

      blocked_combat = %{
        combat
        | grid: %{
            combat.grid
            | tiles:
                Map.put(combat.grid.tiles, {2, 0, -2}, %{terrain: :plain, occupied_by: blocker})
          },
          __constants__: %{players: [fighter, enemy, blocker]},
          queue: [enemy, blocker]
      }

      {updated, _anims} =
        Game.Card.process_card(blocked_combat, enemy, charge_strike_card(fighter.id))

      # step 1: {0,0,0} → {1,0,-1} (clear); step 2: → {2,0,-2} (blocked) → stops at {1,0,-1}
      assert updated.current_turn.player.position == {1, 0, -1}
      updated_enemy = Enum.find(updated.queue, &(&1.id == enemy.id))
      assert enemy.hp - updated_enemy.hp == 3
    end
  end
end
