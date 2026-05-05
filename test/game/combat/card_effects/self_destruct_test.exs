defmodule Game.Combat.CardEffects.SelfDestructTest do
  use ExUnit.Case, async: true

  alias Game.Combat.CardEffect
  alias Game.Combat.CardEffects.SelfDestruct
  alias Game.{Card, CombatState, Grid, Fixtures}

  setup do
    fighter = Fixtures.fighter()
    mage = %{Fixtures.mage() | position: {1, 0, -1}}

    self_destruct_card = %Card{
      id: 99,
      name: "Self Destruct",
      cost: 0,
      range: 0,
      effects: [%SelfDestruct{}],
      targeting: %{"type" => "character"}
    }

    grid = %Grid{
      tiles: %{
        {0, 0, 0} => %{terrain: :plain, occupied_by: fighter},
        {1, 0, -1} => %{terrain: :plain, occupied_by: mage}
      }
    }

    combat = %CombatState{
      state: :running,
      __constants__: %{players: [fighter, mage]},
      queue: [mage],
      grid: grid,
      current_turn: %{
        starting_position: fighter.position,
        player: fighter,
        card: nil
      }
    }

    {:ok, combat: combat, fighter: fighter, mage: mage, card: self_destruct_card}
  end

  describe "process/3" do
    test "removes the played card from the caster's discard", %{
      combat: combat,
      fighter: fighter,
      card: card
    } do
      # Simulate process_card: card is moved to discard first, then effects run
      fighter_with_card_discarded = %{
        fighter
        | cards: %{fighter.cards | discard: [card | fighter.cards.discard]}
      }

      combat = %{
        combat
        | current_turn: %{
            combat.current_turn
            | player: fighter_with_card_discarded,
              card: card
          }
      }

      updated = CardEffect.process(%SelfDestruct{}, fighter, combat)
      updated_fighter = updated.current_turn.player
      refute Enum.any?(updated_fighter.cards.discard, &(&1.id == card.id))
    end

    test "does not remove other cards from discard", %{
      combat: combat,
      fighter: fighter,
      card: card
    } do
      other_card = %{Fixtures.attack_card() | id: 50}

      fighter_with_cards = %{
        fighter
        | cards: %{
            fighter.cards
            | discard: [card, other_card]
          }
      }

      combat = %{
        combat
        | current_turn: %{
            combat.current_turn
            | player: fighter_with_cards,
              card: card
          }
      }

      updated = CardEffect.process(%SelfDestruct{}, fighter, combat)
      updated_fighter = updated.current_turn.player
      assert Enum.any?(updated_fighter.cards.discard, &(&1.id == other_card.id))
      refute Enum.any?(updated_fighter.cards.discard, &(&1.id == card.id))
    end

    test "is a no-op when current_turn.card is nil", %{combat: combat, fighter: fighter} do
      # No card in current_turn means we don't know what to remove
      updated = CardEffect.process(%SelfDestruct{}, fighter, combat)
      assert updated == combat
    end
  end

  describe "full process_card integration" do
    test "card is absent from all piles after being played with self_destruct", %{
      combat: combat,
      fighter: fighter,
      card: card
    } do
      fighter_with_card = %{
        fighter
        | cards: %{fighter.cards | hand: [card]}
      }

      # current_turn.card must be set (as it would be after pick_card in real play)
      combat = %{
        combat
        | state: :running,
          current_turn: %{combat.current_turn | player: fighter_with_card, card: card}
      }

      {updated, _anims} = Card.process_card(combat, fighter, card)
      updated_fighter = updated.current_turn.player

      refute Enum.any?(updated_fighter.cards.hand, &(&1.id == card.id))
      refute Enum.any?(updated_fighter.cards.discard, &(&1.id == card.id))
      refute Enum.any?(updated_fighter.cards.draw, &(&1.id == card.id))
    end
  end

  describe "protocol contracts" do
    test "get_description/1" do
      assert is_binary(CardEffect.get_description(%SelfDestruct{}))
    end

    test "get_icon/1" do
      assert is_binary(CardEffect.get_icon(%SelfDestruct{}))
    end

    test "get_value_label/1" do
      assert is_binary(CardEffect.get_value_label(%SelfDestruct{}))
    end

    test "animate/1" do
      assert %{label: _, color: _} = CardEffect.animate(%SelfDestruct{})
    end

    test "params/1 returns []" do
      assert CardEffect.params(%SelfDestruct{}) == []
    end
  end
end
