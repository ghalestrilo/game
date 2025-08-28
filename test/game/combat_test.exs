defmodule Game.CombatTest do
  use ExUnit.Case, async: true
  alias Game.{Combat, Character, Fixtures, Grid, CombatState}

  @cards %{
    attack: %{Fixtures.attack_card() | id: 1, effect: {:damage, 5}},
    fireball: %{Fixtures.fireball_card() | id: 2},
    heal: %{Fixtures.heal_card() | id: 3},
    range_limited: %{Fixtures.attack_card() | id: 4, range: 1},
    lethal: %{Fixtures.lethal_card() | id: 5},
    expensive: Fixtures.expensive_card(),
    long_range: Fixtures.long_range_card()
  }

  setup do
    # Initialize a mage and a fighter from fixtures
    mage = Fixtures.mage()
    fighter = Fixtures.warrior()

    # Prepare characters with cards in hand - mage should have empty hand for tests
    fighter = %{fighter | cards: %{fighter.cards | hand: Map.keys(@cards)}}
    mage = %{mage | cards: %{mage.cards | hand: Map.keys(@cards)}}

    # Create a small grid with mage and fighter placed adjacently
    grid = %Grid{
      tiles: %{
        {0, 0, 0} => %{terrain: :plain, occupied_by: fighter},
        {1, 0, -1} => %{terrain: :plain, occupied_by: nil},
        {2, 0, -2} => %{terrain: :plain, occupied_by: mage},
        {3, 0, -3} => %{terrain: :plain, occupied_by: nil}
      }
    }

    # Create the combat state with fighter's turn first
    combat_state = %CombatState{
      state: :running,
      __constants__: %{
        players: [fighter, mage]
      },
      queue: [fighter, mage],
      grid: grid,
      current_turn: %{
        starting_position: fighter.position,
        player: fighter,
        card: nil
      }
    }

    {:ok, combat_state: combat_state, fighter: fighter, mage: mage}
  end

  describe "pick_card" do
    setup %{combat_state: combat_state, fighter: fighter} do
      # Execute the action
      result = Combat.process_action(combat_state, {:pick_card, fighter, @cards.attack})

      {:ok, result: result, combat_state: combat_state, fighter: fighter}
    end

    test "returns ok tuple when card is in hand", %{result: result} do
      assert {:ok, _} = result
    end

    test "changes state to card_selected", %{result: {:ok, updated_combat}} do
      assert updated_combat.state == :card_selected
    end

    test "sets current_turn.card to selected card", %{result: {:ok, updated_combat}} do
      assert updated_combat.current_turn.card == @cards.attack
    end
  end

  describe "pick_card when card is not in hand" do
    setup %{combat_state: combat_state, fighter: fighter} do
      result = Combat.process_action(combat_state, {:pick_card, fighter, @cards.expensive})

      {:ok, result: result}
    end

    test "returns error when card is not in hand", %{result: result} do
      assert {:error, _} = result
    end
  end

  describe "play_card with not enough AP" do
    setup %{combat_state: combat_state, fighter: fighter} do
      {:ok, updated_combat} =
        Combat.process_action(combat_state, {:pick_card, fighter_with_low_ap, @cards.expensive})

      result = Combat.process_action(updated_combat, {:play_card, {2, 0, -2}})

      {:ok, result: result, combat_state: updated_combat}
    end

    test "returns error when not enough AP", %{result: result} do
      assert {:error, _} = result
    end

    test "fighter remains unchanged", %{combat_state: combat_state} do
      assert combat_state.current_turn.player.ap == 1
    end
  end

  describe "play_card with damage effect" do
    setup %{combat_state: combat_state, fighter: fighter, mage: mage} do
      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: fighter},
          {1, 0, -1} => %{terrain: :plain, occupied_by: nil},
          {2, 0, -2} => %{terrain: :plain, occupied_by: mage}
        }
      }

      # First pick the card
      {:ok, updated_combat} =
        Combat.process_action(combat_state, {:pick_card, fighter, @cards.attack})

      result = Combat.process_action(updated_combat, {:play_card, {2, 0, -2}})

      {:ok, result: result, fighter: fighter, original_mage: mage, test_card: @cards.attack}
    end

    test "returns ok tuple", %{result: result} do
      assert {:ok, _} = result
    end

    test "reduces target HP by damage amount", %{
      result: {:ok, updated_combat},
      original_mage: original_mage,
      test_card: test_card
    } do
      updated_mage = Enum.find(updated_combat.queue, &(&1.id == original_mage.id))
      {:damage, damage_amount} = test_card.effect
      assert updated_mage.hp == original_mage.hp - damage_amount
    end

    test "deducts AP from player by card cost", %{
      result: {:ok, updated_combat},
      fighter: fighter,
      test_card: test_card
    } do
      updated_fighter = updated_combat.current_turn.player
      assert updated_fighter.ap == fighter.ap - test_card.cost
    end

    test "moves card to discard pile", %{
      result: {:ok, updated_combat},
      test_card: test_card
    } do
      updated_fighter = updated_combat.current_turn.player
      assert Enum.any?(updated_fighter.cards.discard, fn c -> c.id == test_card.id end)
      refute Enum.any?(updated_fighter.cards.hand, fn c -> c.id == test_card.id end)
    end
  end

  describe "play_card with heal effect" do
    setup %{combat_state: combat_state, fighter: fighter} do
      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: fighter_with_low_hp},
          {1, 0, -1} => %{terrain: :plain, occupied_by: nil},
          {2, 0, -2} => %{terrain: :plain, occupied_by: nil}
        }
      }

      {:ok, updated_combat} =
        Combat.process_action(combat_state, {:pick_card, fighter_with_low_hp, @cards.heal})

      result = Combat.process_action(updated_combat, {:play_card, {0, 0, 0}})

      {:ok, result: result, heal_card: @cards.heal, original_hp: 10}
    end

    test "increases target HP by heal amount", %{
      result: {:ok, updated_combat},
      original_hp: original_hp,
      heal_card: heal_card
    } do
      updated_fighter = updated_combat.current_turn.player
      {:heal, heal_amount} = heal_card.effect
      assert updated_fighter.hp == original_hp + heal_amount
    end

    test "deducts AP for heal cost", %{result: {:ok, updated_combat}, heal_card: heal_card} do
      updated_fighter = updated_combat.current_turn.player
      assert updated_fighter.ap == 3 - heal_card.cost
    end
  end

  describe "move beyond range" do
    setup %{combat_state: combat_state, fighter: fighter} do
      # 3 spaces away, beyond fighter's movement range of 2
      target_position = {3, 0, -3}
      result = Combat.process_action(combat_state, {:move, fighter, target_position})

      {:ok, result: result, combat_state: combat_state, fighter: fighter}
    end

    test "returns error when move is beyond range", %{result: result} do
      assert {:error, _} = result
    end

    test "fighter position remains unchanged", %{combat_state: combat_state, fighter: fighter} do
      assert combat_state.current_turn.player.position == fighter.position
    end
  end

  describe "move to occupied tile" do
    setup %{combat_state: combat_state, fighter: fighter, mage: mage} do
      target_position = mage.position
      result = Combat.process_action(combat_state, {:move, fighter, target_position})

      {:ok, result: result, combat_state: combat_state, fighter: fighter}
    end

    test "returns error when move is to occupied tile", %{result: result} do
      assert {:error, _} = result
    end

    test "fighter position remains unchanged", %{combat_state: combat_state, fighter: fighter} do
      assert combat_state.current_turn.player.position == fighter.position
    end
  end

  describe "move within range" do
    setup %{combat_state: combat_state, fighter: fighter} do
      # Adjacent empty tile
      target_position = {1, 0, -1}
      result = Combat.process_action(combat_state, {:move, fighter, target_position})

      {:ok, result: result, target_position: target_position}
    end

    test "returns ok tuple when move is valid", %{result: result} do
      assert {:ok, _} = result
    end

    test "updates fighter position", %{
      result: {:ok, updated_combat},
      target_position: target_position
    } do
      assert updated_combat.current_turn.player.position == target_position
    end

    test "updates grid to show fighter in new position", %{
      result: {:ok, updated_combat},
      target_position: target_position
    } do
      {:ok, character_at_position} = Grid.get_object(updated_combat.grid, target_position)
      assert character_at_position.id == updated_combat.current_turn.player.id
    end
  end

  describe "skip_turn" do
    setup %{combat_state: combat_state, fighter: fighter, mage: mage} do
      result = Combat.process_action(combat_state, {:skip_turn, fighter})

      {:ok, result: result, mage: mage}
    end

    test "returns ok tuple", %{result: result} do
      assert {:ok, _} = result
    end

    test "updates current_turn to next character", %{result: {:ok, updated_combat}, mage: mage} do
      assert updated_combat.current_turn.player.id == mage.id
    end

    test "next character has 5 cards in hand", %{result: {:ok, updated_combat}} do
      assert length(updated_combat.current_turn.player.cards.hand) == 5
    end

    test "next character has full AP", %{result: {:ok, updated_combat}, mage: mage} do
      assert updated_combat.current_turn.player.ap == Character.get_max_ap(mage)
    end
  end

  describe "play_card out of range" do
    setup %{combat_state: combat_state, fighter: fighter, mage: mage} do
      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: fighter},
          {1, 0, -1} => %{terrain: :plain, occupied_by: nil},
          {2, 0, -2} => %{terrain: :plain, occupied_by: nil},
          {3, 0, -3} => %{terrain: :plain, occupied_by: mage}
        }
      }

      {:ok, updated_combat} =
        Combat.process_action(combat_state, {:pick_card, fighter, @cards.attack})

      result = Combat.process_action(updated_combat, {:play_card, {3, 0, -3}})

      {:ok, result: result}
    end

    test "returns error when target is out of range", %{result: result} do
      assert {:error, _} = result
    end
  end

  describe "game over check" do
    setup %{combat_state: combat_state, fighter: fighter, mage: mage} do
      # Make sure the grid has characters at correct positions
      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: fighter},
          {1, 0, -1} => %{terrain: :plain, occupied_by: nil},
          {2, 0, -2} => %{terrain: :plain, occupied_by: mage}
        }
      }

      {:ok, updated_combat} =
        Combat.process_action(combat_state, {:pick_card, fighter, @cards.lethal})

      result = Combat.process_action(updated_combat, {:play_card, {2, 0, -2}})

      {:ok, result: result}
    end

    test "game state changes to game_over when character is killed", %{
      result: {:ok, updated_combat}
    } do
      assert updated_combat.state == :game_over
    end

    test "dead character is removed from players list", %{result: {:ok, updated_combat}} do
      assert length(updated_combat.queue) == 1
    end

    test "dead character is removed from queue", %{result: {:ok, updated_combat}} do
      assert length(updated_combat.queue) == 1
    end
  end
end
