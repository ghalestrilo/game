defmodule Game.Combat.CardEffects.DrawTest do
  use ExUnit.Case, async: true

  alias Game.Combat.CardEffect
  alias Game.Combat.CardEffects.Draw
  alias Game.{CombatState, Grid, Fixtures}

  describe "Draw effect" do
    setup do
      warrior = %{
        Fixtures.fighter()
        | cards: %{
            draw: [
              %{Fixtures.attack_card() | id: 1},
              %{Fixtures.attack_card() | id: 2},
              %{Fixtures.attack_card() | id: 3}
            ],
            hand: [],
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

      draw_effect = %Draw{type: :draw, value: 2}

      {:ok, combat_state: combat_state, draw_effect: draw_effect, warrior: warrior}
    end

    test "process/3 draws specified number of cards into hand", %{
      combat_state: combat_state,
      draw_effect: draw_effect,
      warrior: warrior
    } do
      original_hand_size = length(warrior.cards.hand)
      original_draw_pile_size = length(warrior.cards.draw)

      updated_state = CardEffect.process(draw_effect, warrior, combat_state)
      updated_warrior = updated_state.current_turn.player

      assert length(updated_warrior.cards.hand) == original_hand_size + 2
      assert length(updated_warrior.cards.draw) == original_draw_pile_size - 2
    end

    test "get_description/1 returns correct draw description for single card" do
      draw_one = %Draw{type: :draw, value: 1}
      description = CardEffect.get_description(draw_one)
      assert description == "Draw 1 card"
    end

    test "get_description/1 returns correct draw description for multiple cards", %{
      draw_effect: draw_effect
    } do
      description = CardEffect.get_description(draw_effect)
      assert description == "Draw 2 cards"
    end

    test "process/3 when draw pile is empty", %{combat_state: combat_state} do
      warrior_empty_draw = %{
        Fixtures.fighter()
        | cards: %{
            draw: [],
            hand: [],
            discard: [
              %{Fixtures.attack_card() | id: 1},
              %{Fixtures.attack_card() | id: 2}
            ]
          }
      }

      combat_state = %{
        combat_state
        | current_turn: %{combat_state.current_turn | player: warrior_empty_draw}
      }

      draw_effect = %Draw{type: :draw, value: 2}
      updated_state = CardEffect.process(draw_effect, warrior_empty_draw, combat_state)
      updated_warrior = updated_state.current_turn.player

      # Should reshuffle discard pile into draw pile and then draw
      assert length(updated_warrior.cards.hand) > 0
    end
  end
end
