defmodule Game.CardFlowTest do
  use ExUnit.Case
  alias Game.{Combat, Character, Card, Grid}

  describe "turn card flow" do
    setup do
      # Create standard cards for testing
      card1 = %Card{id: "card1", name: "Card 1", cost: 1, effect: {:damage, 5}}
      card2 = %Card{id: "card2", name: "Card 2", cost: 1, effect: {:heal, 3}}

      # Create warrior with cards in all piles
      warrior = %Character{
        id: 1,
        name: "Warrior",
        class: :fighter,
        ap: 3,
        hp: 20,
        position: {0, 0, 0},
        movement_range: 2,
        team: :team1,
        cards: %{
          draw: [
            %{card1 | id: "draw1"},
            %{card1 | id: "draw2"},
            %{card1 | id: "draw3"}
          ],
          hand: [
            %{card1 | id: "hand1"},
            %{card1 | id: "hand2"}
          ],
          discard: [
            %{card1 | id: "discard1"},
            %{card1 | id: "discard2"},
            %{card1 | id: "discard3"},
            %{card1 | id: "discard4"}
          ]
        }
      }

      # Create mage with few cards in draw pile
      mage = %Character{
        id: 2,
        name: "Mage",
        class: :mage,
        ap: 3,
        hp: 15,
        position: {1, 0, -1},
        movement_range: 1,
        team: :team2,
        cards: %{
          draw: [
            %{card2 | id: "draw1"},
            %{card2 | id: "draw2"}
          ],
          hand: [],
          discard: [
            %{card2 | id: "discard1"},
            %{card2 | id: "discard2"},
            %{card2 | id: "discard3"},
            %{card2 | id: "discard4"},
            %{card2 | id: "discard5"}
          ]
        }
      }

      # Create basic grid
      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: warrior},
          {1, 0, -1} => %{terrain: :plain, occupied_by: mage}
        }
      }

      # Create combat with warrior as current player
      combat = %Combat{
        state: :running,
        players: [warrior, mage],
        queue: [warrior, mage],
        grid: grid,
        current_turn: %{
          starting_position: warrior.position,
          player: warrior,
          card: nil
        }
      }

      %{
        combat: combat,
        warrior: warrior,
        mage: mage,
        card1: card1,
        card2: card2
      }
    end

    test "when a turn starts, player should have exactly 5 cards in hand", %{combat: combat} do
      # Assert the starting player (warrior) already has cards in hand from setup
      [current_player | _] = combat.queue
      assert current_player.name == "Warrior"
      assert length(current_player.cards.hand) == 2
    end

    test "when skipping turn, all cards in hand go to discard pile and next player draws 5 cards", %{combat: combat} do
      # Skip warrior's turn
      {:ok, updated_combat} = Combat.process_action(combat, {:skip_turn, hd(combat.queue)})

      # Find warrior in updated player list
      updated_warrior = Enum.find(updated_combat.players, &(&1.id == 1))

      # Warrior's hand should be empty after skipping turn
      assert length(updated_warrior.cards.hand) == 0

      # Warrior's discard pile should have hand cards (2) + previous discards (4) = 6 total
      assert length(updated_warrior.cards.discard) == 6

      # Find mage in updated player list (should be current player now)
      updated_mage = Enum.find(updated_combat.players, &(&1.id == 2))
      [current_player | _] = updated_combat.queue
      assert current_player.id == updated_mage.id

      # Mage should now have exactly 5 cards in hand
      assert length(updated_mage.cards.hand) == 5

      # Since mage only had 2 cards in draw pile, discard pile should have been shuffled
      # Draw pile should now have 2 (original) + 5 (from discard) - 5 (drawn) = 2 cards
      assert length(updated_mage.cards.draw) == 2

      # Discard pile should be empty since all cards were moved to draw pile
      assert length(updated_mage.cards.discard) == 0
    end

    test "when playing a card, it's moved from hand to discard and next player draws 5 cards", %{combat: combat, warrior: warrior} do
      # Get a card from warrior's hand
      [card | _] = warrior.cards.hand

      # First select the card
      {:ok, card_selected_combat} = Combat.process_action(combat, {:pick_card, warrior, card})

      # Then play it on mage's position
      {:ok, updated_combat} = Combat.process_action(card_selected_combat, {:play_card, {1, 0, -1}})

      # Find warrior in updated player list
      updated_warrior = Enum.find(updated_combat.players, &(&1.id == 1))

      # Warrior's hand should be empty after playing card
      assert length(updated_warrior.cards.hand) == 0

      # Warrior's discard pile should have the card that was played plus the rest of the hand
      assert length(updated_warrior.cards.discard) == 6 # 4 original + 2 from hand

      # Find mage in updated player list (should be current player now)
      updated_mage = Enum.find(updated_combat.players, &(&1.id == 2))
      [current_player | _] = updated_combat.queue
      assert current_player.id == updated_mage.id

      # Mage should now have exactly 5 cards in hand
      assert length(updated_mage.cards.hand) == 5

      # Draw pile should have been shuffled with discard
      assert length(updated_mage.cards.draw) == 2
      assert length(updated_mage.cards.discard) == 0
    end

    test "when a player has not enough cards in draw and discard combined, they draw as many as possible", %{combat: combat} do
      # Modify mage to have very few cards total (3 cards)
      mage = Enum.find(combat.players, &(&1.id == 2))
      mage_with_few_cards = %{mage |
        cards: %{
          draw: [%Card{id: "single_draw", name: "Single Draw", cost: 1, effect: {:damage, 1}}],
          hand: [],
          discard: [
            %Card{id: "single_discard1", name: "Discard 1", cost: 1, effect: {:heal, 1}},
            %Card{id: "single_discard2", name: "Discard 2", cost: 1, effect: {:heal, 1}}
          ]
        }
      }

      # Update combat with our modified mage
      combat_with_few_cards = %{combat |
        players: [hd(combat.players), mage_with_few_cards],
        queue: [hd(combat.queue), mage_with_few_cards]
      }

      # Skip warrior's turn to move to mage
      {:ok, updated_combat} = Combat.process_action(combat_with_few_cards, {:skip_turn, hd(combat_with_few_cards.queue)})

      # Find mage in updated players
      updated_mage = Enum.find(updated_combat.players, &(&1.id == 2))

      # Mage should have drawn all 3 available cards
      assert length(updated_mage.cards.hand) == 3
      assert length(updated_mage.cards.draw) == 0
      assert length(updated_mage.cards.discard) == 0
    end
  end
end
