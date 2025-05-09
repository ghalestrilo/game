defmodule Game.CombatTest do
  use ExUnit.Case
  alias Game.{Combat, Character, Card, Grid}

  setup do
    # Create two characters
    warrior = %Character{
      id: 1,
      name: "Warrior",
      class: :fighter,
      ap: 3,
      hp: 20,
      position: {0, 0, 0},
      movement_range: 2,
      team: :team1
    }

    mage = %Character{
      id: 2,
      name: "Mage",
      class: :mage,
      ap: 3,
      hp: 15,
      position: {2, 0, -2},
      movement_range: 1,
      team: :team2
    }

    # Create a basic grid with characters in their positions
    grid = %Grid{
      tiles: %{
        {0, 0, 0} => %{terrain: :plain, occupied_by: warrior},
        {1, 0, -1} => %{terrain: :plain, occupied_by: nil},
        {2, 0, -2} => %{terrain: :plain, occupied_by: mage},
        {3, 0, -3} => %{terrain: :plain, occupied_by: nil}
      }
    }

    # Create some cards
    attack_card = %Card{
      id: 1,
      name: "Strike",
      cost: 1,
      effect: {:damage, 5}
    }

    heal_card = %Card{
      id: 2,
      name: "Heal",
      cost: 2,
      effect: {:heal, 3}
    }

    # Create initial combat state
    combat = %Combat{
      state: :running,
      players: [warrior, mage],
      queue: [warrior, mage],
      grid: grid,
      current_turn: %{starting_position: warrior.position}
    }

    %{
      combat: combat,
      warrior: warrior,
      mage: mage,
      attack_card: attack_card,
      heal_card: heal_card,
      grid: grid
    }
  end

  describe "movement" do
    test "character can move within range", %{combat: combat, warrior: warrior} do
      assert {:ok, updated_combat} = Combat.act(combat, {:move, warrior, {1, 0, -1}})
      [next_player | _] = updated_combat.queue
      # Mage's turn next
      assert next_player.id == 2

      # Find warrior in players list
      moved_warrior = Enum.find(updated_combat.players, &(&1.id == warrior.id))
      assert moved_warrior.position == {1, 0, -1}
    end

    test "character cannot move beyond range", %{combat: combat, warrior: warrior} do
      assert {:error, "Not enough movement"} =
               Combat.act(combat, {:move, warrior, {3, 0, -3}})
    end

    test "character cannot move to blocked tile", %{combat: combat, warrior: warrior} do
      # Update grid to have a blocked tile
      blocked_grid = %{
        combat.grid
        | tiles: Map.put(combat.grid.tiles, {1, 0, -1}, %{terrain: :wall, occupied_by: nil})
      }

      combat = %{combat | grid: blocked_grid}

      assert {:error, "Tile is blocked"} =
               Combat.act(combat, {:move, warrior, {1, 0, -1}})
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
               Combat.act(combat, {:play_card, warrior, attack_card, mage.position})

      # Find mage in updated players list
      updated_mage = Enum.find(updated_combat.players, &(&1.id == mage.id))
      assert updated_mage.hp == mage.hp - 5
    end

    test "character cannot play card without enough AP", %{
      combat: combat,
      warrior: warrior,
      mage: mage
    } do
      # Create expensive card
      expensive_card = %Card{
        id: 3,
        name: "Mega Strike",
        cost: 5,
        effect: {:damage, 10}
      }

      assert {:error, "Not enough AP"} =
               Combat.act(combat, {:play_card, warrior, expensive_card, mage.position})
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

      combat = %{
        combat
        | players: [damaged_warrior, Enum.at(combat.players, 1)],
          queue: [damaged_warrior, Enum.at(combat.queue, 1)],
          grid: updated_grid
      }

      assert {:ok, updated_combat} =
               Combat.act(
                 combat,
                 {:play_card, damaged_warrior, heal_card, damaged_warrior.position}
               )

      updated_warrior = Enum.find(updated_combat.players, &(&1.id == warrior.id))
      # 15 + 3 healing
      assert updated_warrior.hp == 18
    end
  end

  describe "death and game over" do
    test "character dies when HP reaches 0", %{combat: combat, warrior: warrior, mage: mage} do
      # Create lethal damage card
      lethal_card = %Card{
        id: 4,
        name: "Death Strike",
        cost: 1,
        effect: {:damage, 20}
      }

      assert {:ok, updated_combat} =
               Combat.act(combat, {:play_card, warrior, lethal_card, mage.position})

      # Check mage is removed from players and queue
      assert length(updated_combat.players) == 1
      assert length(updated_combat.queue) == 1
      assert Enum.all?(updated_combat.players, &(&1.id != mage.id))
      assert Enum.all?(updated_combat.queue, &(&1.id != mage.id))
    end

    test "game ends when only one team remains", %{combat: combat, warrior: warrior, mage: mage} do
      # Create lethal damage card
      lethal_card = %Card{
        id: 4,
        name: "Death Strike",
        cost: 1,
        effect: {:damage, 20}
      }

      assert {:ok, updated_combat} =
               Combat.act(combat, {:play_card, warrior, lethal_card, mage.position})

      assert updated_combat.state == :game_over
    end
  end

  describe "turn management" do
    test "turn order is maintained after action", %{combat: combat, warrior: warrior} do
      # Warrior moves
      assert {:ok, updated_combat} = Combat.act(combat, {:move, warrior, {1, 0, -1}})

      # Check turn order
      [next_player | _] = updated_combat.queue
      # Mage's turn next
      assert next_player.id == 2
    end

    test "dead characters are removed from turn order", %{
      combat: combat,
      warrior: warrior,
      mage: mage
    } do
      # Create lethal damage card
      lethal_card = %Card{
        id: 4,
        name: "Death Strike",
        cost: 1,
        effect: {:damage, 20}
      }

      assert {:ok, updated_combat} =
               Combat.act(combat, {:play_card, warrior, lethal_card, mage.position})

      # Check turn order only contains warrior
      assert length(updated_combat.queue) == 1
      [remaining_player | _] = updated_combat.queue
      assert remaining_player.id == warrior.id
    end
  end
end
