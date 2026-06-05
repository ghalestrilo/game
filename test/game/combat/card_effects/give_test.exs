defmodule Game.Combat.CardEffects.GiveTest do
  use Game.DataCase, async: true

  alias Game.Combat.CardEffect
  alias Game.Combat.CardEffects.Give
  alias Game.{CombatState, Grid, Fixtures, BaseCards}

  setup do
    {:ok, base_card} =
      BaseCards.create_base_card(%{
        name: "Test Give Card",
        ap: 1,
        headline: "test",
        rarity: :common,
        effects: [%{type: "damage", value: 3}]
      })

    fighter = Fixtures.fighter()
    mage = %{Fixtures.mage() | position: {1, 0, -1}}

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
      current_turn: %{starting_position: fighter.position, player: fighter, card: nil}
    }

    {:ok, combat: combat, fighter: fighter, mage: mage, base_card: base_card}
  end

  describe "process/3 — slug-based lookup" do
    test "adds card to target's hand by slug", %{combat: combat, mage: mage, base_card: base_card} do
      effect = %Give{card: base_card.slug, pile: "hand"}
      updated = CardEffect.process(effect, mage, combat)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert Enum.any?(updated_mage.cards.hand, &(&1.name == base_card.name))
    end

    test "adds card to draw pile by slug", %{combat: combat, mage: mage, base_card: base_card} do
      effect = %Give{card: base_card.slug, pile: "draw"}
      updated = CardEffect.process(effect, mage, combat)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert Enum.any?(updated_mage.cards.draw, &(&1.name == base_card.name))
    end
  end

  describe "process/3 — adds card to target pile" do
    test "adds card to target's hand", %{combat: combat, mage: mage, base_card: base_card} do
      effect = %Give{card: base_card.id, pile: "hand"}
      updated = CardEffect.process(effect, mage, combat)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert Enum.any?(updated_mage.cards.hand, &(&1.name == base_card.name))
    end

    test "adds card to target's draw pile", %{combat: combat, mage: mage, base_card: base_card} do
      effect = %Give{card: base_card.id, pile: "draw"}
      updated = CardEffect.process(effect, mage, combat)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert Enum.any?(updated_mage.cards.draw, &(&1.name == base_card.name))
    end

    test "adds card to target's discard pile", %{combat: combat, mage: mage, base_card: base_card} do
      effect = %Give{card: base_card.id, pile: "discard"}
      updated = CardEffect.process(effect, mage, combat)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert Enum.any?(updated_mage.cards.discard, &(&1.name == base_card.name))
    end

    test "defaults to hand when pile is unrecognized", %{
      combat: combat,
      mage: mage,
      base_card: base_card
    } do
      effect = %Give{card: base_card.id, pile: "unknown"}
      updated = CardEffect.process(effect, mage, combat)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert Enum.any?(updated_mage.cards.hand, &(&1.name == base_card.name))
    end

    test "given card has cost and effects from the base card", %{
      combat: combat,
      mage: mage,
      base_card: base_card
    } do
      effect = %Give{card: base_card.id, pile: "hand"}
      updated = CardEffect.process(effect, mage, combat)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      given = List.first(updated_mage.cards.hand)
      assert given.cost == base_card.ap
      assert given.name == base_card.name
    end

    test "is a no-op when card id is nil", %{combat: combat, mage: mage} do
      effect = %Give{card: nil, pile: "hand"}
      updated = CardEffect.process(effect, mage, combat)
      assert updated == combat
    end

    test "can give to the current player (self-target)", %{
      combat: combat,
      fighter: fighter,
      base_card: base_card
    } do
      effect = %Give{card: base_card.id, pile: "hand"}
      original_hand_size = length(fighter.cards.hand)
      updated = CardEffect.process(effect, fighter, combat)
      assert length(updated.current_turn.player.cards.hand) == original_hand_size + 1
    end
  end

  describe "protocol contracts" do
    test "get_description/1" do
      assert is_binary(CardEffect.get_description(%Give{pile: "hand"}))
    end

    test "get_icon/1" do
      assert is_binary(CardEffect.get_icon(%Give{}))
    end

    test "get_value_label/1" do
      assert is_binary(CardEffect.get_value_label(%Give{}))
    end

    test "animate/1" do
      assert %{label: _, color: _} = CardEffect.animate(%Give{})
    end

    test "params/1 returns [\"card\", \"pile\"]" do
      assert CardEffect.params(%Give{}) == ["card", "pile"]
    end
  end
end
