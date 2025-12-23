defmodule Game.Combat.CardEffects.DiscardTest do
  use ExUnit.Case, async: true

  alias Game.Combat.CardEffect
  alias Game.Combat.CardEffects.Discard
  alias Game.{CombatState, Grid, Fixtures}

  describe "Discard effect" do
    setup do
      warrior = %{
        Fixtures.fighter()
        | cards: %{
            draw: [],
            hand: [
              %{Fixtures.attack_card() | id: 1},
              %{Fixtures.attack_card() | id: 2},
              %{Fixtures.attack_card() | id: 3}
            ],
            discard: []
          }
      }

      mage = Fixtures.mage()

      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: warrior},
          {1, 0, -1} => %{terrain: :plain, occupied_by: mage}
        }
      }

      combat_state = %CombatState{
        state: :running,
        __constants__: %{players: [warrior, mage]},
        queue: [mage],
        grid: grid,
        current_turn: %{
          starting_position: warrior.position,
          player: warrior,
          card: nil
        }
      }

      discard_effect = %Discard{type: :discard, value: 2}

      {:ok, combat_state: combat_state, discard_effect: discard_effect, warrior: warrior}
    end

    test "process/3 discards specified number of cards from hand", %{
      combat_state: combat_state,
      discard_effect: discard_effect,
      warrior: warrior
    } do
      original_hand_size = length(warrior.cards.hand)
      original_discard_size = length(warrior.cards.discard)

      updated_state = CardEffect.process(discard_effect, warrior, combat_state)
      updated_warrior = updated_state.current_turn.player

      assert length(updated_warrior.cards.hand) == original_hand_size - 2
      assert length(updated_warrior.cards.discard) == original_discard_size + 2
    end

    test "get_description/1 returns correct discard description for single card" do
      discard_one = %Discard{type: :discard, value: 1}
      description = CardEffect.get_description(discard_one)
      assert description == "Discard 1 card from target's hand"
    end

    test "get_description/1 returns correct discard description for multiple cards", %{
      discard_effect: discard_effect
    } do
      description = CardEffect.get_description(discard_effect)
      assert description == "Discard 2 cards from target's hand"
    end

    test "process/3 when hand has fewer cards than discard value", %{
      combat_state: combat_state
    } do
      warrior_small_hand = %{
        Fixtures.fighter()
        | cards: %{
            draw: [],
            hand: [%{Fixtures.attack_card() | id: 1}],
            discard: []
          }
      }

      combat_state = %{
        combat_state
        | current_turn: %{combat_state.current_turn | player: warrior_small_hand}
      }

      discard_effect = %Discard{type: :discard, value: 5}
      updated_state = CardEffect.process(discard_effect, warrior_small_hand, combat_state)
      updated_warrior = updated_state.current_turn.player

      # Should only discard what's available
      assert length(updated_warrior.cards.hand) == 0
      assert length(updated_warrior.cards.discard) == 1
    end

    test "process/3 when hand is empty", %{combat_state: combat_state} do
      warrior_empty_hand = %{
        Fixtures.fighter()
        | cards: %{
            draw: [],
            hand: [],
            discard: []
          }
      }

      combat_state = %{
        combat_state
        | current_turn: %{combat_state.current_turn | player: warrior_empty_hand}
      }

      discard_effect = %Discard{type: :discard, value: 2}
      updated_state = CardEffect.process(discard_effect, warrior_empty_hand, combat_state)
      updated_warrior = updated_state.current_turn.player

      # Should handle gracefully
      assert length(updated_warrior.cards.hand) == 0
      assert length(updated_warrior.cards.discard) == 0
    end
  end
end
