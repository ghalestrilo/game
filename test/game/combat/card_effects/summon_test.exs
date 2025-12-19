defmodule Game.Combat.CardEffects.SummonTest do
  use Game.DataCase

  alias Game.Combat.CardEffect
  alias Game.Combat.CardEffects.Summon
  alias Game.{CombatState, Grid, Fixtures, Content, BaseDecks, BaseCards}

  setup do
    # Create a basic attack card for the deck
    {:ok, attack_card} =
      BaseCards.create_base_card(%{
        name: "Attack",
        ap: 1,
        effects: [%{"type" => "damage", "value" => 1}],
        headline: "Deal 1 damage",
        rarity: :common
      })

    # Create a deck for the summon class
    {:ok, summon_deck} =
      BaseDecks.create_base_deck(%{
        "name" => "Minion Deck",
        "base_deck_cards" => [
          %{"card_id" => attack_card.id, "count" => 5}
        ]
      })

    # Create a base class that can be summoned
    {:ok, minion_class} =
      Content.create_base_class(%{
        class: "minion",
        base_hp: 5,
        base_ap: 2,
        base_movement: 2,
        deck_id: summon_deck.id
      })

    warrior = Fixtures.warrior()
    mage = Fixtures.mage()

    grid = %Grid{
      tiles: %{
        {0, 0, 0} => %{terrain: :plain, occupied_by: warrior},
        {1, 0, -1} => %{terrain: :plain, occupied_by: nil},
        {2, 0, -2} => %{terrain: :plain, occupied_by: mage}
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

    summon_effect = %Summon{type: :summon, value: "minion"}
    target_position = {1, 0, -1}

    {:ok,
     combat_state: combat_state,
     summon_effect: summon_effect,
     target_position: target_position,
     warrior: warrior,
     minion_class: minion_class
    }
  end

  describe "Summon effect" do
    test "process/3 summons a character at target position", %{
      combat_state: combat_state,
      summon_effect: summon_effect,
      target_position: target_position,
      warrior: warrior
    } do
      updated_state = CardEffect.process(summon_effect, target_position, combat_state)

      # Check that a new character was added to the queue
      assert length(updated_state.queue) == length(combat_state.queue) + 1

      # Get the summoned character (should be at the end of the queue)
      summoned_character = List.last(updated_state.queue)

      # Verify the summoned character has correct properties
      assert summoned_character.position == target_position
      assert summoned_character.team == warrior.team
      assert summoned_character.hp == 5
      assert summoned_character.ap == 2
      assert summoned_character.movement_range == 2
    end

    test "process/3 places summoned character on the grid", %{
      combat_state: combat_state,
      summon_effect: summon_effect,
      target_position: target_position
    } do
      updated_state = CardEffect.process(summon_effect, target_position, combat_state)

      # Check that the grid tile is now occupied
      {:ok, character_at_position} = Grid.get_object(updated_state.grid, target_position)
      assert character_at_position != nil
      assert character_at_position.position == target_position
    end

    test "process/3 assigns unique ID to summoned character", %{
      combat_state: combat_state,
      summon_effect: summon_effect,
      target_position: target_position
    } do
      updated_state = CardEffect.process(summon_effect, target_position, combat_state)

      all_characters = [updated_state.current_turn.player | updated_state.queue]

      # Check that all characters have unique IDs
      all_ids = Enum.map(all_characters, & &1.id)
      assert length(all_ids) == length(Enum.uniq(all_ids))
    end

    test "process/3 summoned character belongs to same team as summoner", %{
      combat_state: combat_state,
      summon_effect: summon_effect,
      target_position: target_position,
      warrior: warrior
    } do
      updated_state = CardEffect.process(summon_effect, target_position, combat_state)

      summoned_character = List.last(updated_state.queue)
      assert summoned_character.team == warrior.team
    end

    test "get_description/1 returns correct summon description", %{summon_effect: summon_effect} do
      description = CardEffect.get_description(summon_effect)
      assert description == "Summon a minion at target tile"
    end

    test "process/3 loads character data from database", %{
      combat_state: combat_state,
      summon_effect: summon_effect,
      target_position: target_position,
      minion_class: minion_class
    } do
      updated_state = CardEffect.process(summon_effect, target_position, combat_state)

      summoned_character = List.last(updated_state.queue)

      # Verify the summoned character matches the base class data
      assert summoned_character.hp == minion_class.base_hp
      assert summoned_character.ap == minion_class.base_ap
      assert summoned_character.movement_range == minion_class.base_movement
    end
  end
end
