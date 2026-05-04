defmodule Game.Combat.CardEffects.UnholyPactTest do
  use Game.DataCase, async: true

  alias Game.{Card, CombatState, Grid, Fixtures, FormulaAliases}

  # caster_hand_size counts target.cards.hand via reduce
  @caster_hand_size_expression %{
    "reduce" => [
      %{"var" => ["target.cards.hand"]},
      %{"+" => [%{"var" => "accumulator"}, 1]},
      0
    ]
  }

  @unholy_pact %Card{
    id: 99,
    name: "Unholy Pact",
    cost: 0,
    effects: [
      %{"type" => "heal", "value" => %{"alias" => ["caster_hand_size"]}},
      %{"type" => "discard", "value" => %{"alias" => ["caster_hand_size"]}}
    ]
  }

  setup do
    {:ok, _} =
      FormulaAliases.create_formula_alias(%{
        name: "caster_hand_size",
        expression: @caster_hand_size_expression
      })

    hand = [
      %{Fixtures.attack_card() | id: 10},
      %{Fixtures.attack_card() | id: 11},
      %{Fixtures.attack_card() | id: 12}
    ]

    # Note: @unholy_pact (id 99) is NOT in the hand. process_card will still call
    # discard_card on it, moving it to discard before effects run. The formula then
    # sees hand size = 3 (unchanged), heal = +3, discard effect removes all 3 hand
    # cards. Final discard = [played_card] + [3 hand cards] = 4 total.
    caster = %{
      Fixtures.fighter()
      | hp: 10,
        max_hp: 20,
        cards: %{draw: [], hand: hand, discard: []}
    }

    mage = Fixtures.mage()

    grid = %Grid{
      tiles: %{
        {0, 0, 0} => %{terrain: :plain, occupied_by: caster},
        {1, 0, -1} => %{terrain: :plain, occupied_by: mage}
      }
    }

    combat_state = %CombatState{
      state: :running,
      __constants__: %{players: [caster, mage]},
      queue: [mage],
      grid: grid,
      current_turn: %{
        starting_position: caster.position,
        player: caster,
        card: nil
      }
    }

    %{combat_state: combat_state, caster: caster, hand_size: length(hand)}
  end

  describe "Unholy Pact" do
    test "heals caster by the number of cards in their hand", %{
      combat_state: combat_state,
      caster: caster,
      hand_size: hand_size
    } do
      {updated_state, _anims} = Card.process_card(combat_state, caster, @unholy_pact)

      updated_caster = updated_state.current_turn.player
      assert updated_caster.hp == caster.hp + hand_size
    end

    test "discards all cards from caster's hand", %{
      combat_state: combat_state,
      caster: caster,
      hand_size: hand_size
    } do
      {updated_state, _anims} = Card.process_card(combat_state, caster, @unholy_pact)

      updated_caster = updated_state.current_turn.player
      assert updated_caster.cards.hand == []
      # played card goes to discard first, then the full hand is discarded by the effect
      assert length(updated_caster.cards.discard) == hand_size + 1
    end

    test "heal and discard values are both derived from the same initial hand size", %{
      combat_state: combat_state,
      caster: caster,
      hand_size: hand_size
    } do
      {updated_state, _anims} = Card.process_card(combat_state, caster, @unholy_pact)

      updated_caster = updated_state.current_turn.player
      # heal used hand_size, discard used hand_size — discard pile = played card + full hand
      assert updated_caster.hp == caster.hp + hand_size
      assert updated_caster.cards.hand == []
      assert length(updated_caster.cards.discard) == hand_size + 1
    end

    test "does nothing when hand is empty", %{combat_state: combat_state, caster: caster} do
      empty_hand_caster = %{caster | cards: %{draw: [], hand: [], discard: []}}

      combat_state = %{
        combat_state
        | current_turn: %{combat_state.current_turn | player: empty_hand_caster}
      }

      {updated_state, _anims} =
        Card.process_card(combat_state, empty_hand_caster, @unholy_pact)

      updated_caster = updated_state.current_turn.player
      assert updated_caster.hp == empty_hand_caster.hp
      assert updated_caster.cards.hand == []
      # only the played card itself ends up in discard
      assert length(updated_caster.cards.discard) == 1
    end
  end
end
