defmodule Game.CombatTest do
  use ExUnit.Case
  alias Game.Combat
  alias Game.Fixtures

  setup do
    combat = Fixtures.basic_combat()
    warrior = Fixtures.warrior()
    mage = Fixtures.mage()
    attack_card = Fixtures.attack_card()
    heal_card = Fixtures.heal_card()

    %{
      combat: combat,
      warrior: warrior,
      mage: mage,
      attack_card: attack_card,
      heal_card: heal_card,
      grid: combat.grid
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
      assert {:ok, updated_combat} =
               Combat.process_action(updated_combat, {:move, moved_warrior, {0, 0, 0}})

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
      # Move mage next to warrior for range
      adjacent_mage = %{mage | position: {1, 0, -1}}
      updated_grid = %{
        combat.grid
        | tiles: Map.put(
            combat.grid.tiles,
            adjacent_mage.position,
            %{terrain: :plain, occupied_by: adjacent_mage}
          )
      }

      updated_combat = %{
        combat
        | players: [warrior, adjacent_mage],
          queue: [warrior, adjacent_mage],
          grid: updated_grid
      }

      # First pick the card
      assert {:ok, card_selected_combat} =
               Combat.process_action(updated_combat, {:pick_card, warrior, attack_card})

      # Then play the card
      assert {:ok, updated_combat} =
               Combat.process_action(card_selected_combat, {:play_card, adjacent_mage.position})

      # Find mage in updated players list
      updated_mage = Enum.find(updated_combat.players, &(&1.id == adjacent_mage.id))
      assert updated_mage.hp == mage.hp - 5
    end

    test "character cannot play card without enough AP", %{
      combat: combat,
      warrior: warrior,
      mage: mage
    } do
      # First pick the expensive card
      expensive_card = Fixtures.expensive_card()

      assert {:ok, card_selected_combat} =
               Combat.process_action(combat, {:pick_card, warrior, expensive_card})

      # Then try to play the card - should fail due to insufficient AP
      assert {:error, "Not enough AP"} =
               Combat.process_action(card_selected_combat, {:play_card, mage.position})
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

      # First pick the heal card
      assert {:ok, card_selected_combat} =
               Combat.process_action(updated_combat, {:pick_card, damaged_warrior, heal_card})

      # Then play the card on self
      assert {:ok, updated_combat} =
               Combat.process_action(card_selected_combat, {:play_card, damaged_warrior.position})

      updated_warrior = Enum.find(updated_combat.players, &(&1.id == warrior.id))
      # 15 + 3 healing
      assert updated_warrior.hp == 18
    end

    test "self-targeting with damage card reduces own HP", %{combat: combat, warrior: warrior} do
      # Ensure it's warrior's turn
      updated_combat = %{combat | queue: [warrior, Enum.at(combat.queue, 1)]}

      # First pick the self harm card
      self_harm_card = Fixtures.self_harm_card()

      assert {:ok, card_selected_combat} =
               Combat.process_action(
                 updated_combat,
                 {:pick_card, warrior, self_harm_card}
               )

      # Then play the card on self
      assert {:ok, updated_combat} =
               Combat.process_action(card_selected_combat, {:play_card, warrior.position})

      updated_warrior = Enum.find(updated_combat.players, &(&1.id == warrior.id))
      assert updated_warrior.hp == warrior.hp - 5
    end
  end

  describe "death and game over" do
    test "character dies when HP reaches 0", %{combat: combat, warrior: warrior, mage: mage} do
      # First pick the lethal card
      lethal_card = Fixtures.lethal_card()

      assert {:ok, card_selected_combat} =
               Combat.process_action(combat, {:pick_card, warrior, lethal_card})

      # Then play the card
      assert {:ok, updated_combat} =
               Combat.process_action(card_selected_combat, {:play_card, mage.position})

      # Check mage is removed from players and queue
      assert length(updated_combat.players) == 1
      assert length(updated_combat.queue) == 1
      assert Enum.all?(updated_combat.players, &(&1.id != mage.id))
      assert Enum.all?(updated_combat.queue, &(&1.id != mage.id))
    end

    test "game ends when only one team remains", %{combat: combat, warrior: warrior, mage: mage} do
      # First pick the lethal card
      lethal_card = Fixtures.lethal_card()

      assert {:ok, card_selected_combat} =
               Combat.process_action(combat, {:pick_card, warrior, lethal_card})

      # Then play the card
      assert {:ok, updated_combat} =
               Combat.process_action(card_selected_combat, {:play_card, mage.position})

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
      # First pick the lethal card
      lethal_card = Fixtures.lethal_card()

      assert {:ok, card_selected_combat} =
               Combat.process_action(combat, {:pick_card, warrior, lethal_card})

      # Then play the card
      assert {:ok, updated_combat} =
               Combat.process_action(card_selected_combat, {:play_card, mage.position})

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
      warrior2 = Fixtures.warrior2()

      updated_grid = %{
        combat.grid
        | tiles:
            Map.put(combat.grid.tiles, warrior2.position, %{
              terrain: :plain,
              occupied_by: warrior2
            })
      }

      updated_combat = %{
        combat
        | players: [warrior, warrior2, Enum.at(combat.players, 1)],
          queue: [warrior, warrior2, Enum.at(combat.queue, 1)],
          grid: updated_grid
      }

      # First pick the lethal card
      lethal_card = Fixtures.lethal_card()

      assert {:ok, card_selected_combat} =
               Combat.process_action(
                 updated_combat,
                 {:pick_card, warrior, lethal_card}
               )

      # Then play the card on warrior2
      assert {:ok, updated_combat} =
               Combat.process_action(
                 card_selected_combat,
                 {:play_card, warrior2.position}
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
      # Ensure it's warrior's turn and mage is at a position warrior can target
      # Update mage position to be adjacent to warrior for range issues
      adjacent_mage = %{mage | position: {1, 0, -1}}
      updated_grid = %{
        combat.grid
        | tiles: Map.put(
            combat.grid.tiles,
            adjacent_mage.position,
            %{terrain: :plain, occupied_by: adjacent_mage}
          )
      }

      updated_combat = %{
        combat
        | queue: [warrior, adjacent_mage],
          players: [warrior, adjacent_mage],
          grid: updated_grid
      }

      # Test healing beyond max HP
      # First pick the max heal card
      max_heal_card = Fixtures.max_heal_card()

      assert {:ok, card_selected_combat} =
               Combat.process_action(
                 updated_combat,
                 {:pick_card, warrior, max_heal_card}
               )

      # Then play the card on self
      assert {:ok, updated_combat} =
               Combat.process_action(card_selected_combat, {:play_card, warrior.position})

      updated_warrior = Enum.find(updated_combat.players, &(&1.id == warrior.id))
      # Should not exceed max HP
      assert updated_warrior.hp == warrior.hp

      # Test negative damage
      # Ensure it's still warrior's turn
      updated_combat = %{
        updated_combat
        | queue: [
            updated_warrior,
            Enum.find(updated_combat.players, &(&1.id == adjacent_mage.id))
          ]
      }

      # First pick the negative damage card
      negative_damage_card = Fixtures.negative_damage_card()

      assert {:ok, card_selected_combat} =
               Combat.process_action(
                 updated_combat,
                 {:pick_card, updated_warrior, negative_damage_card}
               )

      # Then play the card on mage (who should be within range now)
      assert {:ok, updated_combat} =
               Combat.process_action(card_selected_combat, {:play_card, adjacent_mage.position})

      updated_mage = Enum.find(updated_combat.players, &(&1.id == mage.id))
      # Negative damage should heal
      assert updated_mage.hp == mage.hp + 5
    end

    test "turn order edge cases", %{combat: combat, warrior: warrior} do
      # Test that turn order is maintained after multiple actions
      assert {:ok, updated_combat} = Combat.process_action(combat, {:move, warrior, {1, 0, -1}})
      moved_warrior = Enum.find(updated_combat.players, &(&1.id == warrior.id))

      assert {:ok, updated_combat} =
               Combat.process_action(updated_combat, {:move, moved_warrior, {0, 0, 0}})

      moved_warrior = Enum.find(updated_combat.players, &(&1.id == warrior.id))

      assert {:ok, updated_combat} =
               Combat.process_action(updated_combat, {:move, moved_warrior, {1, 0, -1}})

      # Check turn order is still correct
      [next_player | _] = updated_combat.queue
      assert next_player.id == warrior.id
    end
  end

  describe "when a character plays a card" do
    setup %{combat: combat, warrior: warrior, heal_card: heal_card} do
      # Ensure it's warrior's turn
      updated_combat = %{combat | queue: [warrior | Enum.drop(combat.queue, 1)]}

      # First pick the card
      {:ok, card_selected_combat} = Combat.process_action(updated_combat, {:pick_card, warrior, heal_card})

      # Then play the card on self (avoiding range issues)
      {:ok, updated_combat} = Combat.process_action(card_selected_combat, {:play_card, warrior.position})

      %{
        initial_combat: updated_combat,
        card_selected_combat: card_selected_combat,
        updated_combat: updated_combat,
        warrior: warrior,
        played_card: heal_card
      }
    end

    test "card disappears from hand", %{warrior: warrior, updated_combat: updated_combat, played_card: played_card} do
      updated_warrior = Enum.find(updated_combat.players, &(&1.id == warrior.id))
      refute Enum.any?(updated_warrior.hand, fn card -> card.id == played_card.id end)
    end

    test "only one card is removed if there are multiple copies", %{
      initial_combat: combat,
      warrior: warrior,
      played_card: played_card
    } do
      # Add a duplicate card to warrior's hand
      duplicate_card = %{played_card | id: "duplicate-#{played_card.id}"}
      warrior_with_duplicate = %{warrior | hand: [duplicate_card | warrior.hand]}

      # Update combat state with warrior having duplicate cards
      updated_combat = %{
        combat
        | players: Enum.map(combat.players, fn
            p -> if p.id == warrior.id, do: warrior_with_duplicate, else: p
          end),
          queue: [warrior_with_duplicate | Enum.drop(combat.queue, 1)]
      }

      # First pick the original card
      {:ok, card_selected_combat} = Combat.process_action(updated_combat, {:pick_card, warrior_with_duplicate, played_card})

      # Then play the card on self
      {:ok, after_play_combat} = Combat.process_action(card_selected_combat, {:play_card, warrior_with_duplicate.position})

      # Find updated warrior
      updated_warrior = Enum.find(after_play_combat.players, &(&1.id == warrior.id))

      # The original card should be gone but the duplicate remains
      refute Enum.any?(updated_warrior.hand, fn card -> card.id == played_card.id end)
      assert Enum.any?(updated_warrior.hand, fn card -> card.id == duplicate_card.id end)
    end

    test "card appears in discard pile", %{warrior: warrior, updated_combat: updated_combat, played_card: played_card} do
      updated_warrior = Enum.find(updated_combat.players, &(&1.id == warrior.id))
      assert Enum.any?(updated_warrior.discard, fn card -> card.id == played_card.id end)
    end

    test "effects are applied to target", %{warrior: warrior, updated_combat: updated_combat, played_card: played_card} do
      # For a heal card, check that healing was applied to warrior
      updated_warrior = Enum.find(updated_combat.players, &(&1.id == warrior.id))
      {:heal, value} = played_card.effect
      assert updated_warrior.hp == warrior.hp + value
    end
  end
end
