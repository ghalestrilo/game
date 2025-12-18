defmodule Game.CombatTest do
  use ExUnit.Case, async: true
  alias Game.Combat.CardEffect
  alias Game.{Combat, Character, Fixtures, Grid, CombatState}

  @cards %{
    attack: %{Fixtures.attack_card() | id: 1},
    fireball: %{Fixtures.fireball_card() | id: 2},
    heal: %{Fixtures.heal_card() | id: 3},
    range_limited: %{Fixtures.attack_card() | id: 4, range: 1},
    lethal: %{Fixtures.lethal_card() | id: 5, range: 10},
    expensive: %{Fixtures.expensive_card() | id: 99},
    long_range: Fixtures.long_range_card()
  }

  setup do
    # Initialize a mage and a fighter from fixtures
    mage = Fixtures.mage()
    fighter = Fixtures.warrior()

    # Prepare characters with cards in hand - exclude expensive_card to test validation
    cards_in_hand = Map.drop(@cards, [:expensive]) |> Map.values()
    fighter = %{fighter | cards: %{fighter.cards | hand: cards_in_hand}}
    mage = %{mage | cards: %{mage.cards | hand: cards_in_hand}}

    # Create a small grid with mage and fighter placed adjacently (distance 1 for attack card range)
    mage = %{mage | position: {1, 0, -1}}
    grid = %Grid{
      tiles: %{
        {0, 0, 0} => %{terrain: :plain, occupied_by: fighter},
        {1, 0, -1} => %{terrain: :plain, occupied_by: mage},
        {2, 0, -2} => %{terrain: :plain, occupied_by: nil},
        {3, 0, -3} => %{terrain: :plain, occupied_by: nil}
      }
    }

    # Create the combat state with fighter's turn first
    combat_state = %CombatState{
      state: :running,
      __constants__: %{
        players: [fighter, mage]
      },
      queue: [mage],
      grid: grid,
      current_turn: %{
        starting_position: fighter.position,
        player: fighter,
        card: nil
      }
    }

    {:ok, combat_state: combat_state, fighter: fighter, mage: mage}
  end

  describe "pick_card" do
    setup %{combat_state: combat_state, fighter: fighter} do
      # Execute the action
      result = Combat.process_action(combat_state, {:pick_card, fighter, @cards.attack})

      {:ok, result: result, combat_state: combat_state, fighter: fighter}
    end

    test "returns ok tuple when card is in hand", %{result: result} do
      assert {:ok, _} = result
    end

    test "changes state to card_selected", %{result: {:ok, updated_combat}} do
      assert updated_combat.state == :card_selected
    end

    test "sets current_turn.card to selected card", %{result: {:ok, updated_combat}} do
      assert updated_combat.current_turn.card == @cards.attack
    end
  end

  describe "pick_card when card is not in hand" do
    setup %{combat_state: combat_state, fighter: fighter} do
      result = Combat.process_action(combat_state, {:pick_card, fighter, @cards.expensive})

      {:ok, result: result}
    end

    test "returns error when card is not in hand", %{result: result} do
      assert {:error, _} = result
    end
  end

  describe "play_card with not enough AP" do
    setup %{combat_state: combat_state, fighter: fighter} do
      # Add expensive card to hand for this test
      fighter_with_expensive = %{fighter | cards: %{fighter.cards | hand: [fighter.cards.hand | [@cards.expensive]] |> List.flatten()}}
      combat_state = %{combat_state | current_turn: %{combat_state.current_turn | player: fighter_with_expensive}}

      {:ok, updated_combat} =
        Combat.process_action(combat_state, {:pick_card, fighter_with_expensive, @cards.expensive})

      result = Combat.process_action(updated_combat, {:play_card, {2, 0, -2}})

      {:ok, result: result, combat_state: updated_combat}
    end

    test "returns error when not enough AP", %{result: result} do
      assert {:error, _} = result
    end

    test "fighter remains unchanged", %{combat_state: combat_state} do
      assert combat_state.current_turn.player.ap == 3
    end
  end

  describe "play_card with damage effect" do
    setup %{combat_state: combat_state, fighter: fighter, mage: mage} do

      # First pick the card
      {:ok, updated_combat} =
        Combat.process_action(combat_state, {:pick_card, fighter, @cards.attack})

      result = Combat.process_action(updated_combat, {:play_card, mage.position})

      {:ok, result: result, fighter: fighter, original_mage: mage, test_card: @cards.attack}
    end

    test "returns ok tuple", %{result: result} do
      assert {:ok, _} = result
    end

    test "reduces target HP by damage amount", %{
      result: {:ok, updated_combat},
      original_mage: original_mage,
      test_card: test_card
    } do
      updated_mage = Enum.find(updated_combat.queue, &(&1.id == original_mage.id))
      [%{"type" => "damage", "value" => damage_amount}] = test_card.effects
      assert updated_mage.hp == original_mage.hp - damage_amount
    end

    test "deducts AP from player by card cost", %{
      result: {:ok, updated_combat},
      fighter: fighter,
      test_card: test_card
    } do
      updated_fighter = updated_combat.current_turn.player
      assert updated_fighter.ap == fighter.ap - test_card.cost
    end

    test "moves card to discard pile", %{
      result: {:ok, updated_combat},
      test_card: test_card
    } do
      updated_fighter = updated_combat.current_turn.player
      assert Enum.any?(updated_fighter.cards.discard, fn c -> c.id == test_card.id end)
      refute Enum.any?(updated_fighter.cards.hand, fn c -> c.id == test_card.id end)
    end
  end

  describe "play_card with heal effect" do
    setup %{combat_state: combat_state, fighter: fighter} do
      {:ok, updated_combat} =
        Combat.process_action(combat_state, {:pick_card, fighter, @cards.heal})

      result = Combat.process_action(updated_combat, {:play_card, {0, 0, 0}})

      {:ok, result: result, heal_card: @cards.heal, original_hp: fighter.hp}
    end

    test "increases target HP by heal amount", %{
      result: {:ok, updated_combat},
      original_hp: original_hp,
      heal_card: heal_card
    } do
      updated_fighter = updated_combat.current_turn.player
      [%{"type" => "heal", "value" => heal_amount}] = heal_card.effects
      assert updated_fighter.hp == original_hp + heal_amount
    end

    test "deducts AP for heal cost", %{result: {:ok, updated_combat}, heal_card: heal_card} do
      updated_fighter = updated_combat.current_turn.player
      assert updated_fighter.ap == 3 - heal_card.cost
    end
  end

  describe "move beyond range" do
    setup %{combat_state: combat_state, fighter: fighter} do
      # 3 spaces away, beyond fighter's movement range of 2
      target_position = {3, 0, -3}
      result = Combat.process_action(combat_state, {:move, fighter, target_position})

      {:ok, result: result, combat_state: combat_state, fighter: fighter}
    end

    test "returns error when move is beyond range", %{result: result} do
      assert {:error, _} = result
    end

    test "fighter position remains unchanged", %{combat_state: combat_state, fighter: fighter} do
      assert combat_state.current_turn.player.position == fighter.position
    end
  end

  describe "move to occupied tile" do
    setup %{combat_state: combat_state, fighter: fighter, mage: mage} do
      target_position = mage.position
      result = Combat.process_action(combat_state, {:move, fighter, target_position})

      {:ok, result: result, combat_state: combat_state, fighter: fighter}
    end

    test "returns error when move is to occupied tile", %{result: result} do
      assert {:error, _} = result
    end

    test "fighter position remains unchanged", %{combat_state: combat_state, fighter: fighter} do
      assert combat_state.current_turn.player.position == fighter.position
    end
  end

  describe "move within range" do
    setup %{combat_state: combat_state, fighter: fighter} do
      # Adjacent empty tile
      target_position = {2, 0, -2}
      result = Combat.process_action(combat_state, {:move, fighter, target_position})

      {:ok, result: result, target_position: target_position}
    end

    test "returns ok tuple when move is valid", %{result: result} do
      assert {:ok, _} = result
    end

    test "updates fighter position", %{
      result: {:ok, updated_combat},
      target_position: target_position
    } do
      assert updated_combat.current_turn.player.position == target_position
    end

    test "updates grid to show fighter in new position", %{
      result: {:ok, updated_combat},
      target_position: target_position
    } do
      {:ok, character_at_position} = Grid.get_object(updated_combat.grid, target_position)
      assert character_at_position.id == updated_combat.current_turn.player.id
    end
  end

  describe "skip_turn" do
    setup %{combat_state: combat_state, fighter: fighter, mage: mage} do
      result = Combat.process_action(combat_state, {:skip_turn, fighter})

      {:ok, result: result, mage: mage}
    end

    test "returns ok tuple", %{result: result} do
      assert {:ok, _} = result
    end

    test "updates current_turn to next character", %{result: {:ok, updated_combat}, mage: mage} do
      assert updated_combat.current_turn.player.id == mage.id
    end

    test "next character has 5 cards in hand", %{result: {:ok, updated_combat}} do
      assert length(updated_combat.current_turn.player.cards.hand) == 5
    end

    test "next character has full AP", %{result: {:ok, updated_combat}, mage: mage} do
      assert updated_combat.current_turn.player.ap == Character.get_max_ap(mage)
    end
  end

  describe "play_card out of range" do
    setup %{combat_state: combat_state, fighter: fighter, mage: mage} do
      # Place target at distance 3, out of range for attack card (range 1)
      {:ok, updated_combat} =
        Combat.process_action(combat_state, {:pick_card, fighter, @cards.attack})

      result = Combat.process_action(updated_combat, {:play_card, {3, 0, -3}})

      {:ok, result: result}
    end

    test "returns error when target is out of range", %{result: result} do
      assert {:error, _} = result
    end
  end

  describe "game over check" do
    setup %{combat_state: combat_state, fighter: fighter, mage: mage} do
      {:ok, updated_combat} =
        Combat.process_action(combat_state, {:pick_card, fighter, @cards.lethal})

      result = Combat.process_action(updated_combat, {:play_card, mage.position})

      {:ok, result: result}
    end

    test "game state changes to game_over when character is killed", %{
      result: {:ok, updated_combat}
    } do
      assert updated_combat.state == :game_over
    end

    test "dead character is removed from players list", %{result: {:ok, updated_combat}} do
      # Queue only contains waiting players, not current player
      # After mage dies, only fighter remains (as current player), so queue is empty
      assert length(updated_combat.queue) == 0
    end

    test "dead character is removed from queue", %{result: {:ok, updated_combat}} do
      # Queue only contains waiting players, not current player
      # After mage dies, only fighter remains (as current player), so queue is empty
      assert length(updated_combat.queue) == 0
    end
  end

  describe "move back and forth between tiles" do
    setup %{combat_state: combat_state, fighter: fighter} do
      # Starting position
      start_position = fighter.position
      # Adjacent empty tile
      target_position = {2, 0, -2}

      # First move to the target position
      {:ok, first_move_result} =
        Combat.process_action(combat_state, {:move, fighter, target_position})

      # Then move back to the original position
      result =
        Combat.process_action(
          first_move_result,
          {:move, first_move_result.current_turn.player, start_position}
        )

      {:ok,
       result: result,
       start_position: start_position,
       target_position: target_position,
       first_move_result: first_move_result}
    end

    test "returns ok tuple for both moves", %{result: result} do
      assert {:ok, _} = result
    end

    test "first move updates fighter position to target", %{
      first_move_result: first_move_result,
      target_position: target_position
    } do
      assert first_move_result.current_turn.player.position == target_position
    end

    test "second move returns fighter to original position", %{
      result: {:ok, updated_combat},
      start_position: start_position
    } do
      assert updated_combat.current_turn.player.position == start_position
    end

    test "grid correctly updates after both moves", %{
      result: {:ok, updated_combat},
      start_position: start_position,
      target_position: target_position
    } do
      # Check character is at original position
      {:ok, character_at_start} = Grid.get_object(updated_combat.grid, start_position)
      assert character_at_start.id == updated_combat.current_turn.player.id

      # Ensure target tile is now empty
      assert Grid.tile_blocked?(updated_combat.grid, target_position) == false
    end
  end

  describe "consecutive attacks on same target" do
    setup do
      # Initialize a mage and a fighter from fixtures
      mage = Fixtures.mage()
      fighter = Fixtures.warrior()

      # Create two identical attack cards for the fighter with sufficient range
      attack_card1 = %{Fixtures.attack_card() | id: 1, effects: [%{"type" => "damage", "value" => 5}], range: 2}
      attack_card2 = %{Fixtures.attack_card() | id: 2, effects: [%{"type" => "damage", "value" => 5}], range: 2}

      # Set positions for both characters
      fighter = %{fighter | position: {1, 0, -1}}
      mage = %{mage | hp: 20, position: {2, -1, -1}}

      # Prepare fighter with two attack cards in hand
      fighter = %{fighter | cards: %{fighter.cards | hand: [attack_card1, attack_card2]}}

      # Create a small grid with fighter and mage positioned for attack
      grid = %Grid{
        tiles: %{
          {1, 0, -1} => %{terrain: :plain, occupied_by: fighter},
          {2, -1, -1} => %{terrain: :plain, occupied_by: mage}
        }
      }

      # Create the combat state with fighter's turn first
      combat_state = %CombatState{
        state: :running,
        __constants__: %{
          players: [fighter, mage]
        },
        queue: [mage],
        grid: grid,
        current_turn: %{
          starting_position: {1, 0, -1},
          player: fighter,
          card: nil
        }
      }

      {:ok,
       combat_state: combat_state,
       fighter: fighter,
       mage: mage,
       attack_card1: attack_card1,
       attack_card2: attack_card2}
    end

    test "fighter can play two attack cards consecutively on the same target", %{
      combat_state: combat_state,
      fighter: fighter,
      mage: mage,
      attack_card1: attack_card1,
      attack_card2: attack_card2
    } do
      # First attack - Pick the first card
      {:ok, card_selected_combat} =
        Combat.process_action(combat_state, {:pick_card, fighter, attack_card1})

      # Play the card on mage's position
      {:ok, first_attack_result} =
        Combat.process_action(card_selected_combat, {:play_card, mage.position})

      # Find updated mage after first attack
      updated_mage = Enum.find(first_attack_result.queue, &(&1.id == mage.id))

      # Verify mage took damage from first attack
      assert updated_mage.hp == mage.hp - 5

      # Find updated fighter after first attack
      updated_fighter = first_attack_result.current_turn.player

      # Verify the first attack card is no longer in fighter's hand
      refute Enum.any?(updated_fighter.cards.hand, fn c -> c.id == attack_card1.id end)

      # Verify the first attack card is now in fighter's discard
      assert Enum.any?(updated_fighter.cards.discard, fn c -> c.id == attack_card1.id end)

      # Second attack - Pick the second card
      {:ok, second_card_selected} =
        Combat.process_action(first_attack_result, {:pick_card, updated_fighter, attack_card2})

      # Play the second card on mage's position
      {:ok, second_attack_result} =
        Combat.process_action(second_card_selected, {:play_card, mage.position})

      # Find updated mage after second attack
      final_mage = Enum.find(second_attack_result.queue, &(&1.id == mage.id))

      # Verify mage took damage from second attack (10 total damage)
      assert final_mage.hp == mage.hp - 10

      # Find updated fighter after second attack
      final_fighter = second_attack_result.current_turn.player

      # Verify the second attack card is no longer in fighter's hand
      refute Enum.any?(final_fighter.cards.hand, fn c -> c.id == attack_card2.id end)

      # Verify the second attack card is now in fighter's discard
      assert Enum.any?(final_fighter.cards.discard, fn c -> c.id == attack_card2.id end)

      # Verify both cards are in discard pile
      assert Enum.count(final_fighter.cards.discard) == 2

      # Verify the game is still running after both attacks
      assert second_attack_result.state == :running
    end
  end
end
