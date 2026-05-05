defmodule Game.Seeds.SacrificeCardTest do
  use Game.DataCase, async: true

  alias Game.{Card, Character, CombatState, Grid, Fixtures, BaseCards}

  # Creates the Sacrifice and Cursed Gift cards directly (not from seeds file,
  # which requires a full DB reset). This tests the same effect configuration.
  setup do
    {:ok, sacrifice} =
      BaseCards.create_base_card(%{
        name: "Sacrifice",
        headline: "A cursed gift that wounds its wielder and then vanishes",
        ap: 0,
        effects: [%{type: "damage", value: 2}, %{type: "self_destruct"}],
        targeting: %{"type" => "character"},
        rarity: :rare
      })

    {:ok, cursed_gift} =
      BaseCards.create_base_card(%{
        name: "Cursed Gift",
        headline: "Give an enemy the Sacrifice card",
        ap: 1,
        effects: [%{type: "give", value: %{"card" => sacrifice.id, "pile" => "hand"}}],
        targeting: %{"type" => "character"},
        rarity: :rare
      })

    fighter = Fixtures.fighter()
    mage = %{Fixtures.mage() | position: {1, 0, -1}, max_ap: 3}

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

    {:ok,
     combat: combat,
     fighter: fighter,
     mage: mage,
     sacrifice: sacrifice,
     cursed_gift: cursed_gift}
  end

  defp to_game_card(base_card, id) do
    %Game.Card{
      id: id,
      name: base_card.name,
      cost: base_card.ap,
      effects: base_card.effects,
      range: base_card.range || 1,
      targeting: base_card.targeting
    }
  end

  describe "Sacrifice card" do
    test "deals 2 damage to the target when played", %{
      combat: combat,
      fighter: fighter,
      mage: mage,
      sacrifice: sacrifice
    } do
      card = to_game_card(sacrifice, 99)
      original_hp = mage.hp

      combat = %{combat | current_turn: %{combat.current_turn | card: card}}
      {updated, _anims} = Card.process_card(combat, mage, card)

      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert updated_mage.hp == original_hp - 2
    end

    test "removes itself from all piles after being played", %{
      combat: combat,
      fighter: fighter,
      sacrifice: sacrifice
    } do
      card = to_game_card(sacrifice, 99)

      fighter_with_card = %{fighter | cards: %{fighter.cards | hand: [card]}}

      combat = %{
        combat
        | current_turn: %{combat.current_turn | player: fighter_with_card, card: card}
      }

      {updated, _anims} = Card.process_card(combat, fighter, card)
      updated_fighter = updated.current_turn.player

      refute Enum.any?(updated_fighter.cards.hand, &(&1.id == card.id))
      refute Enum.any?(updated_fighter.cards.discard, &(&1.id == card.id))
      refute Enum.any?(updated_fighter.cards.draw, &(&1.id == card.id))
    end
  end

  describe "Cursed Gift card" do
    test "adds a Sacrifice card to the target's hand", %{
      combat: combat,
      fighter: fighter,
      mage: mage,
      cursed_gift: cursed_gift,
      sacrifice: sacrifice
    } do
      card = to_game_card(cursed_gift, 98)

      combat = %{combat | current_turn: %{combat.current_turn | card: card}}
      {updated, _anims} = Card.process_card(combat, mage, card)

      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert Enum.any?(updated_mage.cards.hand, &(&1.name == "Sacrifice"))
    end

    test "the given Sacrifice card deals damage when played by the recipient", %{
      combat: combat,
      fighter: fighter,
      mage: mage,
      cursed_gift: cursed_gift
    } do
      gift_card = to_game_card(cursed_gift, 98)

      # Fighter gives Sacrifice to mage
      combat = %{combat | current_turn: %{combat.current_turn | card: gift_card}}
      {after_gift, _} = Card.process_card(combat, mage, gift_card)

      # Mage now has Sacrifice in hand — retrieve it
      updated_mage = Enum.find(after_gift.queue, &(&1.id == mage.id))
      [sacrifice_card] = Enum.filter(updated_mage.cards.hand, &(&1.name == "Sacrifice"))

      # Rotate to mage's turn
      mage_combat =
        after_gift
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()

      mage_player = mage_combat.current_turn.player
      original_hp = mage_player.hp

      # Mage plays Sacrifice targeting themselves
      mage_combat = %{mage_combat | current_turn: %{mage_combat.current_turn | card: sacrifice_card}}
      {after_sacrifice, _} = Card.process_card(mage_combat, mage_player, sacrifice_card)

      updated_mage_after = after_sacrifice.current_turn.player
      assert updated_mage_after.hp == original_hp - 2

      # And it's gone from all piles
      refute Enum.any?(updated_mage_after.cards.hand, &(&1.name == "Sacrifice"))
      refute Enum.any?(updated_mage_after.cards.discard, &(&1.name == "Sacrifice"))
      refute Enum.any?(updated_mage_after.cards.draw, &(&1.name == "Sacrifice"))
    end
  end
end
