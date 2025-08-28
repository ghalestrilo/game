defmodule Game.CombatTest do
  use ExUnit.Case, async: true
  alias Game.{Combat, Character, Fixtures, Grid, CombatState}

  @cards %{
    attack: %{Fixtures.attack_card() | id: 1},
    fireball: %{Fixtures.fireball_card() | id: 2},
    heal: %{Fixtures.heal_card() | id: 3},
    range_limited: %{Fixtures.attack_card() | id: 4, range: 1},
    lethal: %{Fixtures.lethal_card() | id: 5},
    expensive: Fixtures.expensive_card()
  }

  setup do
    # Initialize a mage and a fighter from fixtures
    mage = Fixtures.mage()
    fighter = Fixtures.warrior()

    # Prepare characters with cards in hand
    fighter = %{fighter | cards: %{fighter.cards | hand: [@cards.attack]}}
    mage = %{mage | cards: %{mage.cards | hand: [@cards.fireball]}}

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
      players: [fighter, mage],
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

      {:ok, result: result, combat_state: combat_state, fighter: fighter, card: @cards.attack}
    end

    test "returns ok tuple when card is in hand", %{result: result} do
      assert {:ok, _} = result
    end

    test "changes state to card_selected", %{result: {:ok, updated_combat}} do
      assert updated_combat.state == :card_selected
    end

    test "sets current_turn.card to selected card", %{result: {:ok, updated_combat}, card: card} do
      assert updated_combat.current_turn.card == card
    end
  end

  describe "pick_card when card is not in hand" do
    setup %{combat_state: combat_state, fighter: fighter} do
      card = %{@cards.expensive | id: 999}
      result = Combat.process_action(combat_state, {:pick_card, fighter, card})

      {:ok, result: result}
    end

    test "returns error when card is not in hand", %{result: result} do
      assert {:error, _} = result
    end
  end

  describe "play_card with not enough AP" do
    setup %{combat_state: combat_state, fighter: fighter} do
      # Update fighter to have low AP and the expensive card in hand
      fighter_with_low_ap = %{fighter | ap: 1, cards: %{fighter.cards | hand: [@cards.expensive]}}

      # Update the combat state
      combat_state = %{
        combat_state
        | current_turn: %{combat_state.current_turn | player: fighter_with_low_ap}
      }

      # First pick the card
      {:ok, updated_combat} =
        Combat.process_action(combat_state, {:pick_card, fighter_with_low_ap, @cards.expensive})

      # Now try to play the card
      target_position = {2, 0, -2}
      result = Combat.process_action(updated_combat, {:play_card, target_position})

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
      # First pick the card
      {:ok, updated_combat} =
        Combat.process_action(combat_state, {:pick_card, fighter, @cards.attack})

      # Then play the card targeting the mage
      target_position = {2, 0, -2}
      result = Combat.process_action(updated_combat, {:play_card, target_position})

      {:ok,
       result: result, original_combat: updated_combat, fighter: fighter, original_mage: mage}
    end

    test "returns ok tuple", %{result: result} do
      assert {:ok, _} = result
    end

    test "reduces target HP by damage amount", %{
      result: {:ok, updated_combat},
      original_mage: original_mage
    } do
      updated_mage = Enum.find(updated_combat.players, &(&1.id == original_mage.id))
      assert updated_mage.hp == original_mage.hp - 5
    end

    test "deducts AP from player by card cost", %{
      result: {:ok, updated_combat},
      fighter: fighter
    } do
      updated_fighter = updated_combat.current_turn.player
      assert updated_fighter.ap == fighter.ap - @cards.attack.cost
    end

    test "moves card to discard pile", %{result: {:ok, updated_combat}} do
      updated_fighter = updated_combat.current_turn.player
      assert Enum.any?(updated_fighter.cards.discard, fn c -> c.id == @cards.attack.id end)
      refute Enum.any?(updated_fighter.cards.hand, fn c -> c.id == @cards.attack.id end)
    end
  end

  describe "play_card with heal effect" do
    setup %{combat_state: combat_state, fighter: fighter} do
      # Fighter with lower HP and the heal card
      fighter_with_low_hp = %{fighter | hp: 10, cards: %{fighter.cards | hand: [@cards.heal]}}

      # Update the combat state
      combat_state = %{
        combat_state
        | current_turn: %{combat_state.current_turn | player: fighter_with_low_hp}
      }

      # First pick the heal card
      {:ok, updated_combat} =
        Combat.process_action(combat_state, {:pick_card, fighter_with_low_hp, @cards.heal})

      # Then play the heal card on self
      target_position = {0, 0, 0}
      result = Combat.process_action(updated_combat, {:play_card, target_position})

      {:ok, result: result, combat_state: updated_combat}
    end

    test "increases target HP by heal amount", %{result: {:ok, updated_combat}} do
      updated_fighter = updated_combat.current_turn.player
      # 10 + 3
      assert updated_fighter.hp == 13
    end

    test "deducts AP for heal cost", %{result: {:ok, updated_combat}} do
      updated_fighter = updated_combat.current_turn.player
      # 3 - 2
      assert updated_fighter.ap == 1
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
    setup %{combat_state: combat_state, fighter: fighter} do
      # Update fighter to have range limited card
      fighter = %{fighter | cards: %{fighter.cards | hand: [@cards.range_limited]}}

      # Update combat state
      combat_state = %{
        combat_state
        | current_turn: %{combat_state.current_turn | player: fighter}
      }

      # First pick the card
      {:ok, updated_combat} =
        Combat.process_action(combat_state, {:pick_card, fighter, @cards.range_limited})

      # Try to play card on a target that's too far away
      # This is 3 units away, beyond the card's range of 1
      target_position = {3, 0, -3}
      result = Combat.process_action(updated_combat, {:play_card, target_position})

      {:ok, result: result}
    end

    test "returns error when target is out of range", %{result: result} do
      assert {:error, _} = result
    end
  end

  describe "game over check" do
    setup %{combat_state: combat_state, fighter: fighter} do
      # Update fighter to have lethal card
      fighter = %{fighter | cards: %{fighter.cards | hand: [@cards.lethal]}}

      # Update combat state
      combat_state = %{
        combat_state
        | current_turn: %{combat_state.current_turn | player: fighter}
      }

      # First pick the lethal card
      {:ok, updated_combat} =
        Combat.process_action(combat_state, {:pick_card, fighter, @cards.lethal})

      # Play the lethal card on the mage
      target_position = {2, 0, -2}
      result = Combat.process_action(updated_combat, {:play_card, target_position})

      {:ok, result: result}
    end

    test "game state changes to game_over when character is killed", %{
      result: {:ok, updated_combat}
    } do
      assert updated_combat.state == :game_over
    end

    test "dead character is removed from players list", %{result: {:ok, updated_combat}} do
      assert length(updated_combat.players) == 1
    end

    test "dead character is removed from queue", %{result: {:ok, updated_combat}} do
      assert length(updated_combat.queue) == 1
    end
  end
end
