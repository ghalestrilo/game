defmodule Game.TurnTransitionsTest do
  use ExUnit.Case
  alias Game.{Combat, Character, Fixtures, CombatState}

  setup do
    # Set up cards for testing
    card1 = %Game.Card{id: "card1", name: "Card 1", cost: 1, effects: [{:damage, 1}]}
    card2 = %Game.Card{id: "card2", name: "Card 2", cost: 1, effects: [{:damage, 2}]}
    card3 = %Game.Card{id: "card3", name: "Card 3", cost: 1, effects: [{:damage, 3}]}
    card4 = %Game.Card{id: "card4", name: "Card 4", cost: 1, effects: [{:damage, 4}]}
    card5 = %Game.Card{id: "card5", name: "Card 5", cost: 1, effects: [{:damage, 5}]}
    card6 = %Game.Card{id: "card6", name: "Card 6", cost: 1, effects: [{:damage, 6}]}

    # Get base fixtures
    warrior = Fixtures.warrior()
    mage = Fixtures.mage()
    combat = Fixtures.basic_combat()

    # Warrior with 2 cards in hand and 6 in draw
    warrior_with_cards = %{
      warrior
      | cards: %{
          draw: [card1, card2, card3, card4, card5, card6],
          hand: [card4, card5],
          discard: []
        }
    }

    # Mage with 5 cards in draw and empty hand
    mage_with_cards = %{
      mage
      | cards: %{
          draw: [card1, card2, card3, card4, card5],
          hand: [],
          discard: []
        }
    }

    # Update combat state with our custom characters
    updated_combat = %{
      combat
      | players: [warrior_with_cards, mage_with_cards],
        queue: [warrior_with_cards, mage_with_cards],
        current_turn: %{combat.current_turn | player: warrior_with_cards}
    }

    %{
      combat: updated_combat,
      warrior: warrior_with_cards,
      mage: mage_with_cards,
      card1: card1,
      card2: card2,
      cards: [card1, card2, card3, card4, card5, card6]
    }
  end

  describe "skip turn action" do
    test "skipping turn transitions to the next player", %{
      combat: combat,
      warrior: warrior,
      mage: mage
    } do
      # Skip the warrior's turn
      assert {:ok, updated_combat} = Combat.process_action(combat, {:skip_turn, warrior})

      # Check turn has moved to the mage
      [next_player | _] = updated_combat.queue
      assert next_player.id == mage.id

      # Check current_turn is updated
      assert updated_combat.current_turn.player.id == mage.id
      assert updated_combat.current_turn.starting_position == mage.position
    end

    test "cannot skip turn when it's not your turn", %{combat: combat, mage: mage} do
      # Mage tries to skip turn during warrior's turn
      assert {:error, "Not player's turn"} = Combat.process_action(combat, {:skip_turn, mage})
    end
  end

  describe "end-of-turn card management" do
    test "hand is discarded at end of turn", %{combat: combat, warrior: warrior} do
      # Warrior starts with 2 cards in hand
      assert length(warrior.cards.hand) == 2

      # Skip turn which should discard the hand
      assert {:ok, updated_combat} = Combat.process_action(combat, {:skip_turn, warrior})

      # Check warrior's hand is empty
      updated_warrior = Enum.find(updated_combat.players, &(&1.id == warrior.id))
      assert length(updated_warrior.cards.hand) == 0

      # Check cards moved to discard pile
      assert length(updated_warrior.cards.discard) == 2
    end
  end

  describe "start-of-turn card management" do
    test "next player draws cards at start of turn", %{
      combat: combat,
      warrior: warrior,
      mage: mage
    } do
      # Mage starts with empty hand
      assert length(mage.cards.hand) == 0

      # Skip turn which should trigger the mage's turn start
      assert {:ok, updated_combat} = Combat.process_action(combat, {:skip_turn, warrior})

      # Find the updated mage
      updated_mage = Enum.find(updated_combat.players, &(&1.id == mage.id))

      # Verify they drew 5 cards at the start of their turn
      assert length(updated_mage.cards.hand) == 5
    end

    test "only draws cards up to default hand size of 5", %{
      combat: combat,
      warrior: warrior,
      mage: mage,
      cards: cards
    } do
      # Give mage 3 cards in hand
      mage_with_hand = %{
        mage
        | cards: %{
            draw: [
              Enum.at(cards, 0),
              Enum.at(cards, 1),
              Enum.at(cards, 2),
              Enum.at(cards, 3),
              Enum.at(cards, 4)
            ],
            hand: [Enum.at(cards, 0), Enum.at(cards, 1), Enum.at(cards, 2)],
            discard: []
          }
      }

      # Update combat
      combat_with_mage = %{
        combat
        | players: [warrior, mage_with_hand],
          queue: [warrior, mage_with_hand]
      }

      # Skip warrior's turn
      assert {:ok, updated_combat} =
               Combat.process_action(combat_with_mage, {:skip_turn, warrior})

      # Find the updated mage
      updated_mage = Enum.find(updated_combat.players, &(&1.id == mage.id))

      # Verify they only drew 2 more cards (to reach hand size of 5)
      assert length(updated_mage.cards.hand) == 5
    end
  end

  describe "full turn transition sequence" do
    test "turn transition correctly handles discard then draw sequence", %{
      combat: combat,
      warrior: warrior,
      mage: mage
    } do
      # Warrior starts with 2 cards in hand, mage starts with 0
      assert length(warrior.cards.hand) == 2
      assert length(mage.cards.hand) == 0

      # Skip turn
      assert {:ok, updated_combat} = Combat.process_action(combat, {:skip_turn, warrior})

      # Verify warrior's hand was discarded
      updated_warrior = Enum.find(updated_combat.players, &(&1.id == warrior.id))
      assert length(updated_warrior.cards.hand) == 0
      assert length(updated_warrior.cards.discard) == 2

      # Verify mage drew 5 cards
      updated_mage = Enum.find(updated_combat.players, &(&1.id == mage.id))
      assert length(updated_mage.cards.hand) == 5
    end

    test "cards are reshuffled when draw pile doesn't have enough cards", %{
      combat: combat,
      warrior: warrior,
      mage: mage,
      cards: cards
    } do
      # Set up mage with 0 cards in hand, 2 in draw, 3 in discard
      mage_with_low_draw = %{
        mage
        | cards: %{
            draw: [Enum.at(cards, 0), Enum.at(cards, 1)],
            hand: [],
            discard: [Enum.at(cards, 2), Enum.at(cards, 3), Enum.at(cards, 4)]
          }
      }

      # Update combat
      combat_with_mage = %{
        combat
        | players: [warrior, mage_with_low_draw],
          queue: [warrior, mage_with_low_draw]
      }

      # Skip warrior's turn
      assert {:ok, updated_combat} =
               Combat.process_action(combat_with_mage, {:skip_turn, warrior})

      # Find the updated mage
      updated_mage = Enum.find(updated_combat.players, &(&1.id == mage.id))

      # Verify they drew 5 cards (all available)
      assert length(updated_mage.cards.hand) == 5

      # Verify discard pile is now empty
      assert length(updated_mage.cards.discard) == 0

      # Verify draw pile is also empty (all 5 cards are now in hand)
      assert length(updated_mage.cards.draw) == 0
    end
  end
end
