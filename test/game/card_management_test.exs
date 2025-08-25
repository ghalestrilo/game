defmodule Game.CardManagementTest do
  use ExUnit.Case
  alias Game.{Character, Combat}

  describe "character card management" do
    setup do
      # Create a character with 3 cards in draw, 2 in hand, 1 in discard
      card1 = %Game.Card{id: "card1", name: "Card 1", cost: 1, effect: {:damage, 1}}
      card2 = %Game.Card{id: "card2", name: "Card 2", cost: 1, effect: {:damage, 2}}
      card3 = %Game.Card{id: "card3", name: "Card 3", cost: 1, effect: {:damage, 3}}
      card4 = %Game.Card{id: "card4", name: "Card 4", cost: 1, effect: {:damage, 4}}
      card5 = %Game.Card{id: "card5", name: "Card 5", cost: 1, effect: {:damage, 5}}
      card6 = %Game.Card{id: "card6", name: "Card 6", cost: 1, effect: {:damage, 6}}

      character = %Character{
        id: 1,
        name: "Test Character",
        class: :fighter,
        ap: 3,
        hp: 20,
        position: {0, 0, 0},
        movement_range: 2,
        team: :team1,
        cards: %{
          draw: [card1, card2, card3],
          hand: [card4, card5],
          discard: [card6]
        }
      }

      %{
        character: character,
        card1: card1,
        card2: card2,
        card3: card3,
        card4: card4,
        card5: card5,
        card6: card6
      }
    end

    test "moving a card between piles", %{character: character, card4: card4} do
      # Move card from hand to discard
      updated_character = Character.move_card(character, card4, :hand, :discard)

      # Card should no longer be in hand
      refute Enum.any?(updated_character.cards.hand, fn c -> c.id == card4.id end)
      # Card should be in discard
      assert Enum.any?(updated_character.cards.discard, fn c -> c.id == card4.id end)

      # Ensure we still have the right total number of cards
      assert length(updated_character.cards.draw) == 3
      assert length(updated_character.cards.hand) == 1
      assert length(updated_character.cards.discard) == 2

      # The total number of cards should remain the same
      total_cards_before = length(character.cards.draw) + length(character.cards.hand) + length(character.cards.discard)
      total_cards_after = length(updated_character.cards.draw) + length(updated_character.cards.hand) + length(updated_character.cards.discard)
      assert total_cards_before == total_cards_after
    end

    test "drawing cards from draw pile to hand", %{character: character} do
      # Draw 2 cards
      updated_character = Character.draw_cards(character, 2)

      # Hand should have 2 more cards
      assert length(updated_character.cards.hand) == 4
      # Draw should have 2 fewer cards
      assert length(updated_character.cards.draw) == 1
      # Discard should be unchanged
      assert length(updated_character.cards.discard) == 1

      # The total number of cards should remain the same
      total_cards_before = length(character.cards.draw) + length(character.cards.hand) + length(character.cards.discard)
      total_cards_after = length(updated_character.cards.draw) + length(updated_character.cards.hand) + length(updated_character.cards.discard)
      assert total_cards_before == total_cards_after
    end

    test "discarding a card from hand", %{character: character, card5: card5} do
      # Discard a card
      updated_character = Character.discard_card(character, card5)

      # Card should no longer be in hand
      refute Enum.any?(updated_character.cards.hand, fn c -> c.id == card5.id end)
      # Card should be in discard
      assert Enum.any?(updated_character.cards.discard, fn c -> c.id == card5.id end)

      # Hand should have 1 fewer card
      assert length(updated_character.cards.hand) == 1
      # Discard should have 1 more card
      assert length(updated_character.cards.discard) == 2
      # Draw should be unchanged
      assert length(updated_character.cards.draw) == 3

      # The total number of cards should remain the same
      total_cards_before = length(character.cards.draw) + length(character.cards.hand) + length(character.cards.discard)
      total_cards_after = length(updated_character.cards.draw) + length(updated_character.cards.hand) + length(updated_character.cards.discard)
      assert total_cards_before == total_cards_after
    end

    test "shuffling discard into draw pile", %{character: character} do
      # Shuffle discard into draw
      updated_character = Character.shuffle_discard_into_draw(character)

      # Draw should now have discard cards + original draw cards
      assert length(updated_character.cards.draw) == 4
      # Discard should be empty
      assert length(updated_character.cards.discard) == 0
      # Hand should be unchanged
      assert length(updated_character.cards.hand) == 2

      # The total number of cards should remain the same
      total_cards_before = length(character.cards.draw) + length(character.cards.hand) + length(character.cards.discard)
      total_cards_after = length(updated_character.cards.draw) + length(updated_character.cards.hand) + length(updated_character.cards.discard)
      assert total_cards_before == total_cards_after
    end
  end

  describe "combat card management" do
    setup do
      # Create cards
      card1 = %Game.Card{id: "card1", name: "Card 1", cost: 1, effect: {:damage, 1}}
      card2 = %Game.Card{id: "card2", name: "Card 2", cost: 1, effect: {:damage, 2}}
      card3 = %Game.Card{id: "card3", name: "Card 3", cost: 1, effect: {:heal, 3}}

      # Create player with cards
      player = %Character{
        id: 1,
        name: "Player",
        class: :fighter,
        ap: 3,
        hp: 20,
        position: {0, 0, 0},
        movement_range: 2,
        team: :team1,
        cards: %{
          draw: [],
          hand: [card1, card2],
          discard: []
        }
      }

      # Create target with cards
      target = %Character{
        id: 2,
        name: "Target",
        class: :mage,
        ap: 3,
        hp: 15,
        position: {1, 0, -1},
        movement_range: 1,
        team: :team2,
        cards: %{
          draw: [],
          hand: [card3],
          discard: []
        }
      }

      # Create grid
      grid = %Game.Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: player},
          {1, 0, -1} => %{terrain: :plain, occupied_by: target}
        }
      }

      # Create combat state
      combat = %Combat{
        state: :running,
        players: [player, target],
        queue: [player, target],
        grid: grid,
        current_turn: %{
          starting_position: player.position,
          player: player,
          card: nil
        }
      }

      %{
        combat: combat,
        player: player,
        target: target,
        card1: card1,
        card2: card2,
        card3: card3
      }
    end

    test "playing a card moves it to discard pile", %{combat: combat, player: player, target: target, card1: card1} do
      # Add range to the card so it can hit the target
      card1_with_range = %{card1 | range: 1}

      # Create a clean player with just the ranged card in hand
      player_with_ranged_card = %{player | cards: %{
        draw: [],
        hand: [card1_with_range],
        discard: []
      }}

      # Update combat with the modified player
      updated_combat = %{
        combat |
        players: [player_with_ranged_card, Enum.at(combat.players, 1)],
        queue: [player_with_ranged_card, Enum.at(combat.queue, 1)],
        current_turn: %{combat.current_turn | player: player_with_ranged_card}
      }

      # First pick the card
      assert {:ok, card_selected_combat} = Combat.process_action(updated_combat, {:pick_card, player_with_ranged_card, card1_with_range})

      # Then play the card on target
      assert {:ok, updated_combat} = Combat.process_action(card_selected_combat, {:play_card, target.position})

      # Find updated player
      updated_player = Enum.find(updated_combat.players, &(&1.id == player.id))

      # Card should no longer be in hand with the same ID
      refute Enum.any?(updated_player.cards.hand, fn c -> c.id == card1_with_range.id end)

      # Card should be in discard
      assert Enum.any?(updated_player.cards.discard, fn c -> c.id == card1_with_range.id end)

      # The total number of cards should remain the same
      total_cards_before = length(player_with_ranged_card.cards.draw) + length(player_with_ranged_card.cards.hand) + length(player_with_ranged_card.cards.discard)
      total_cards_after = length(updated_player.cards.draw) + length(updated_player.cards.hand) + length(updated_player.cards.discard)
      assert total_cards_before == total_cards_after
    end

    test "drawing cards when draw pile is empty shuffles discard", %{combat: combat, player: player} do
      # Get first card from player's hand
      first_card = player.cards.hand |> hd

      # Move all cards to discard
      player = %{player | cards: %{draw: [], hand: [], discard: [first_card]}}

      # Update combat state with modified player
      combat = %{
        combat |
        players: [player, Enum.at(combat.players, 1)],
        queue: [player, Enum.at(combat.queue, 1)]
      }

      # Draw cards
      updated_combat = Combat.draw_cards_for_player(combat, player, 1)

      # Find updated player
      updated_player = Enum.find(updated_combat.players, &(&1.id == player.id))

      # Player should have drawn a card from shuffled discard
      assert length(updated_player.cards.hand) == 1
      assert length(updated_player.cards.discard) == 0

      # The card that was in discard should now be in hand
      assert Enum.any?(updated_player.cards.hand, fn c -> c.id == first_card.id end)
    end
  end
end
