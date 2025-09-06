defmodule Game.ConsecutiveCardAttacksTest do
  use ExUnit.Case
  alias Game.{Combat, CombatState, Character, Card, Grid, Fixtures}

  describe "consecutive attacks on same target" do
    setup do
      # Initialize a mage and a fighter from fixtures
      mage = Fixtures.mage()
      fighter = Fixtures.warrior()

      # Create two identical attack cards for the fighter with sufficient range
      attack_card1 = %{Fixtures.attack_card() | id: 1, effects: [{:damage, 5}], range: 2}
      attack_card2 = %{Fixtures.attack_card() | id: 2, effects: [{:damage, 5}], range: 2}

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
        queue: [fighter, mage],
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
      refute Enum.any?(updated_fighter.cards.hand, fn card -> card.id == attack_card1.id end)

      # Verify the first attack card is now in fighter's discard
      assert Enum.any?(updated_fighter.cards.discard, fn card -> card.id == attack_card1.id end)

      # Second attack - Pick the second card
      {:ok, second_card_selected} =
        Combat.process_action(first_attack_result, {:pick_card, updated_fighter, attack_card2})

      # Play the second card on mage's position
      result = Combat.process_action(second_card_selected, {:play_card, mage.position})

      # Print debug information
      IO.puts("Debug - Combat state before second attack:")
      IO.inspect(second_card_selected, pretty: true)
      IO.puts("\nDebug - Mage position:")
      IO.inspect(mage.position, pretty: true)
      IO.puts("\nDebug - Result of second attack:")
      IO.inspect(result, pretty: true)

      {:ok, second_attack_result} = result

      # Find updated mage after second attack
      final_mage = Enum.find(second_attack_result.queue, &(&1.id == mage.id))

      # Verify mage took damage from second attack (10 total damage)
      assert final_mage.hp == mage.hp - 10

      # Find updated fighter after second attack
      final_fighter = second_attack_result.current_turn.player

      # Verify the second attack card is no longer in fighter's hand
      refute Enum.any?(final_fighter.cards.hand, fn card -> card.id == attack_card2.id end)

      # Verify the second attack card is now in fighter's discard
      assert Enum.any?(final_fighter.cards.discard, fn card -> card.id == attack_card2.id end)

      # Verify both cards are in discard pile
      assert Enum.count(final_fighter.cards.discard) == 2

      # Verify the game is still running after both attacks
      assert second_attack_result.state == :running
    end
  end
end
