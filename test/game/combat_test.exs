defmodule Game.CombatTest do
  use ExUnit.Case
  alias Game.{Combat, Character, Card, Grid}
  alias Game.Fixtures

  setup do
    %{
      combat: Fixtures.basic_combat(),
      warrior: Fixtures.warrior(),
      mage: Fixtures.mage(),
      attack_card: Fixtures.attack_card(),
      heal_card: Fixtures.heal_card(),
      grid: Fixtures.basic_grid()
    }
  end

  describe "movement" do
    test "character can move within range", %{combat: combat, warrior: warrior} do
      assert {:ok, updated_combat} = Combat.process_action(combat, {:move, warrior, {1, 0, -1}})
      [next_player | _] = updated_combat.queue
      # Warrior's turn still
      assert next_player.id == warrior.id

      # Find warrior in players list
      moved_warrior = Enum.find(updated_combat.players, &(&1.id == warrior.id))
      assert moved_warrior.position == {1, 0, -1}
    end

    test "character can move multiple times within range", %{combat: combat, warrior: warrior} do
      # First move
      assert {:ok, updated_combat} = Combat.process_action(combat, {:move, warrior, {1, 0, -1}})
      moved_warrior = Enum.find(updated_combat.players, &(&1.id == warrior.id))

      # Second move
      assert {:ok, updated_combat} = Combat.process_action(updated_combat, {:move, moved_warrior, {0, 0, 0}})
      moved_warrior = Enum.find(updated_combat.players, &(&1.id == warrior.id))

      # Third move
      assert {:ok, updated_combat} =
               Combat.process_action(updated_combat, {:move, moved_warrior, {1, 0, -1}})

      # Check turn order hasn't changed
      [next_player | _] = updated_combat.queue
      assert next_player.id == warrior.id

      # Check final position
      moved_warrior = Enum.find(updated_combat.players, &(&1.id == warrior.id))
      assert moved_warrior.position == {1, 0, -1}
    end

    test "character cannot move beyond range from starting position", %{
      combat: combat,
      warrior: warrior
    } do
      assert {:error, "Not enough movement"} =
               Combat.process_action(combat, {:move, warrior, {3, 0, -3}})
    end

    test "character cannot move to blocked tile", %{combat: combat, warrior: warrior} do
      # Update grid to have a blocked tile
      blocked_grid = %{
        combat.grid
        | tiles: Map.put(combat.grid.tiles, {1, 0, -1}, %{terrain: :wall, occupied_by: nil})
      }

      combat = %{combat | grid: blocked_grid}

      assert {:error, "Tile is blocked"} =
               Combat.process_action(combat, {:move, warrior, {1, 0, -1}})
    end
  end

  describe "card playing" do
    test "character can play card with enough AP", %{
      combat: combat,
      warrior: warrior,
      mage: mage,
      attack_card: attack_card
    } do
      assert {:ok, updated_combat} =
               Combat.process_action(combat, {:play_card, warrior, attack_card, mage.position})

      # Find mage in updated players list
      updated_mage = Enum.find(updated_combat.players, &(&1.id == mage.id))
      assert updated_mage.hp == mage.hp - 5
    end

    test "character cannot play card without enough AP", %{
      combat: combat,
      warrior: warrior,
      mage: mage
    } do
      assert {:error, "Not enough AP"} =
               Combat.process_action(combat, {:play_card, warrior, Fixtures.expensive_card(), mage.position})
    end

    test "healing card restores HP", %{combat: combat, warrior: warrior, heal_card: heal_card} do
      # Damage warrior first
      # 20 - 5 damage
      damaged_warrior = %{warrior | hp: 15}

      # Update grid with damaged warrior
      updated_grid = %{
        combat.grid
        | tiles:
            Map.update!(combat.grid.tiles, warrior.position, fn tile ->
              %{tile | occupied_by: damaged_warrior}
            end)
      }

      # Update combat state with damaged warrior
      updated_combat = %{
        combat
        | players: [damaged_warrior, Enum.at(combat.players, 1)],
          queue: [damaged_warrior, Enum.at(combat.queue, 1)],
          grid: updated_grid
      }

      assert {:ok, updated_combat} =
               Combat.process_action(
                 updated_combat,
                 {:play_card, damaged_warrior, heal_card, damaged_warrior.position}
               )

      updated_warrior = Enum.find(updated_combat.players, &(&1.id == warrior.id))
      # 15 + 3 healing
      assert updated_warrior.hp == 18
    end

    test "self-targeting with damage card reduces own HP", %{combat: combat, warrior: warrior} do
      # Ensure it's warrior's turn
      updated_combat = %{combat | queue: [warrior, Enum.at(combat.queue, 1)]}

      assert {:ok, updated_combat} =
               Combat.process_action(
                 updated_combat,
                 {:play_card, warrior, Fixtures.self_harm_card(), warrior.position}
               )

      updated_warrior = Enum.find(updated_combat.players, &(&1.id == warrior.id))
      assert updated_warrior.hp == warrior.hp - 5
    end
  end

  describe "death and game over" do
    test "character dies when HP reaches 0", %{combat: combat, warrior: warrior, mage: mage} do
      assert {:ok, updated_combat} =
               Combat.process_action(combat, {:play_card, warrior, Fixtures.lethal_card(), mage.position})

      # Check mage is removed from players and queue
      assert length(updated_combat.players) == 1
      assert length(updated_combat.queue) == 1
      assert Enum.all?(updated_combat.players, &(&1.id != mage.id))
      assert Enum.all?(updated_combat.queue, &(&1.id != mage.id))
    end

    test "game ends when only one team remains", %{combat: combat, warrior: warrior, mage: mage} do
      assert {:ok, updated_combat} =
               Combat.process_action(combat, {:play_card, warrior, Fixtures.lethal_card(), mage.position})

      assert updated_combat.state == :game_over
    end
  end

  describe "turn management" do
    test "turn order is maintained after movement", %{combat: combat, warrior: warrior} do
      # Warrior moves
      assert {:ok, updated_combat} = Combat.process_action(combat, {:move, warrior, {1, 0, -1}})

      # Check turn order hasn't changed
      [next_player | _] = updated_combat.queue
      assert next_player.id == warrior.id
    end

    test "dead characters are removed from turn order", %{
      combat: combat,
      warrior: warrior,
      mage: mage
    } do
      assert {:ok, updated_combat} =
               Combat.process_action(combat, {:play_card, warrior, Fixtures.lethal_card(), mage.position})

      # Check turn order only contains warrior
      assert length(updated_combat.queue) == 1
      [remaining_player | _] = updated_combat.queue
      assert remaining_player.id == warrior.id
    end
  end

  describe "edge cases" do
    test "invalid action returns error", %{combat: combat} do
      assert {:error, "Invalid action"} = Combat.process_action(combat, :invalid_action)
    end

    test "invalid state returns error" do
      assert {:error, "Invalid state"} = Combat.process_action(:invalid_state, :move)
    end

    test "multiple characters on same team", %{combat: combat, warrior: warrior} do
      # Update grid and combat state
      updated_grid = %{
        combat.grid
        | tiles:
            Map.put(combat.grid.tiles, Fixtures.warrior2().position, %{
              terrain: :plain,
              occupied_by: Fixtures.warrior2()
            })
      }

      updated_combat = %{
        combat
        | players: [warrior, Fixtures.warrior2(), Enum.at(combat.players, 1)],
          queue: [warrior, Fixtures.warrior2(), Enum.at(combat.queue, 1)],
          grid: updated_grid
      }

      # Test that game doesn't end when one team member dies
      assert {:ok, updated_combat} =
               Combat.process_action(
                 updated_combat,
                 {:play_card, warrior, Fixtures.lethal_card(), Fixtures.warrior2().position}
               )

      assert updated_combat.state == :running
      assert length(updated_combat.players) == 2
    end

    test "movement edge cases", %{combat: combat, warrior: warrior} do
      # Test moving to same position
      assert {:error, "Tile is blocked"} =
               Combat.process_action(combat, {:move, warrior, warrior.position})

      # Test moving to occupied position
      assert {:error, "Tile is blocked"} =
               Combat.process_action(combat, {:move, warrior, {2, 0, -2}})
    end

    test "card effect edge cases", %{combat: combat, warrior: warrior, mage: mage} do
      # Ensure it's warrior's turn
      updated_combat = %{combat | queue: [warrior, mage]}

      # Test healing beyond max HP
      assert {:ok, updated_combat} =
               Combat.process_action(
                 updated_combat,
                 {:play_card, warrior, Fixtures.max_heal_card(), warrior.position}
               )

      updated_warrior = Enum.find(updated_combat.players, &(&1.id == warrior.id))
      # Should not exceed max HP
      assert updated_warrior.hp == warrior.hp

      # Test negative damage
      # Ensure it's still warrior's turn
      updated_combat = %{updated_combat | queue: [warrior, mage]}

      assert {:ok, updated_combat} =
               Combat.process_action(
                 updated_combat,
                 {:play_card, warrior, Fixtures.negative_damage_card(), mage.position}
               )

      updated_mage = Enum.find(updated_combat.players, &(&1.id == mage.id))
      # Negative damage should heal
      assert updated_mage.hp == mage.hp + 5
    end

    test "turn order edge cases", %{combat: combat, warrior: warrior, mage: mage} do
      # Test that turn order is maintained after multiple actions
      assert {:ok, updated_combat} = Combat.process_action(combat, {:move, warrior, {1, 0, -1}})
      moved_warrior = Enum.find(updated_combat.players, &(&1.id == warrior.id))

      assert {:ok, updated_combat} = Combat.process_action(updated_combat, {:move, moved_warrior, {0, 0, 0}})
      moved_warrior = Enum.find(updated_combat.players, &(&1.id == warrior.id))

      assert {:ok, updated_combat} =
               Combat.process_action(updated_combat, {:move, moved_warrior, {1, 0, -1}})

      # Check turn order is still correct
      [next_player | _] = updated_combat.queue
      assert next_player.id == warrior.id
    end
  end
end
