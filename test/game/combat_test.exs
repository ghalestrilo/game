defmodule Game.CombatTest do
  use ExUnit.Case, async: true
  alias Game.{Combat, Character, Fixtures, Grid, CombatState}

  alias Game.{Card, MapObject}

  defp play_card(combat, position) do
    case Combat.process_action(combat, {:play_card, position}) do
      {:ok, updated, _animations} -> {:ok, updated}
      other -> other
    end
  end

  @cards %{
    attack: %{Fixtures.attack_card() | id: 1},
    fireball: %{Fixtures.fireball_card() | id: 2},
    heal: %{Fixtures.heal_card() | id: 3},
    range_limited: %{Fixtures.attack_card() | id: 4, range: 1},
    lethal: %{Fixtures.lethal_card() | id: 5, range: 10},
    expensive: %{Fixtures.expensive_card() | id: 99},
    long_range: Fixtures.long_range_card()
  }

  setup do
    # Initialize a mage and a fighter from fixtures
    mage = Fixtures.mage()
    fighter = Fixtures.fighter()

    # Prepare characters with cards in hand - exclude expensive_card to test validation
    cards_in_hand = Map.drop(@cards, [:expensive]) |> Map.values()
    fighter = %{fighter | cards: %{fighter.cards | hand: cards_in_hand}}
    mage = %{mage | cards: %{mage.cards | hand: cards_in_hand}}

    # Create a small grid with mage and fighter placed adjacently (distance 1 for attack card range)
    mage = %{mage | position: {1, 0, -1}}

    grid = %Grid{
      tiles: %{
        {0, 0, 0} => %{terrain: :plain, occupied_by: fighter},
        {1, 0, -1} => %{terrain: :plain, occupied_by: mage},
        {2, 0, -2} => %{terrain: :plain, occupied_by: nil},
        {3, 0, -3} => %{terrain: :plain, occupied_by: nil},
        {0, -1, 1} => %{terrain: :plain, occupied_by: nil},
        {1, -1, 0} => %{terrain: :plain, occupied_by: nil},
        {2, -1, -1} => %{terrain: :plain, occupied_by: nil}
      }
    }

    # Create the combat state with fighter's turn first
    combat_state = %CombatState{
      state: :running,
      __constants__: %{
        players: [fighter, mage]
      },
      queue: [mage],
      grid: grid,
      current_turn: %{
        starting_position: fighter.position,
        player: fighter,
        card: nil
      }
    }

    {:ok, combat_state: combat_state, fighter: fighter, mage: mage}
  end

  describe "build_tile_overlay with map objects on grid" do
    test "does not crash when grid tiles contain wall objects", %{
      combat_state: combat_state,
      fighter: fighter
    } do
      grid_with_walls = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: fighter},
          {1, 0, -1} => %{terrain: :plain, objects: [%MapObject.Wall{}], occupied_by: nil},
          {2, 0, -2} => %{terrain: :plain, occupied_by: nil}
        }
      }

      combat = %{combat_state | grid: grid_with_walls}

      # build_tile_overlay calls Jason.encode(combat) internally — this must not raise
      assert {overlay, _blast_map} = Card.build_tile_overlay(@cards.attack, combat)
      assert is_map(overlay)
    end

    test "does not crash when grid tiles contain breakable objects", %{
      combat_state: combat_state,
      fighter: fighter
    } do
      grid_with_breakables = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: fighter},
          {1, 0, -1} => %{
            terrain: :plain,
            objects: [%MapObject.Breakable{hp: 3, max_hp: 3, blocks_movement: true}],
            occupied_by: nil
          },
          {2, 0, -2} => %{terrain: :plain, occupied_by: nil}
        }
      }

      combat = %{combat_state | grid: grid_with_breakables}

      assert {overlay, _blast_map} = Card.build_tile_overlay(@cards.attack, combat)
      assert is_map(overlay)
    end
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
      # Add expensive card to hand for this test
      fighter_with_expensive = %{
        fighter
        | cards: %{
            fighter.cards
            | hand: [fighter.cards.hand | [@cards.expensive]] |> List.flatten()
          }
      }

      combat_state = %{
        combat_state
        | current_turn: %{combat_state.current_turn | player: fighter_with_expensive}
      }

      {:ok, updated_combat} =
        Combat.process_action(
          combat_state,
          {:pick_card, fighter_with_expensive, @cards.expensive}
        )

      result = play_card(updated_combat, {2, 0, -2})

      {:ok, result: result, combat_state: updated_combat}
    end

    test "returns error when not enough AP", %{result: result} do
      assert {:error, _} = result
    end

    test "fighter remains unchanged", %{combat_state: combat_state} do
      assert combat_state.current_turn.player.ap == 3
    end
  end

  describe "play_card with damage effect" do
    setup %{combat_state: combat_state, fighter: fighter, mage: mage} do
      # First pick the card
      {:ok, updated_combat} =
        Combat.process_action(combat_state, {:pick_card, fighter, @cards.attack})

      result = play_card(updated_combat, mage.position)

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
      [%{"type" => "damage", "value" => damage_amount}] = test_card.effects
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
      {:ok, updated_combat} =
        Combat.process_action(combat_state, {:pick_card, fighter, @cards.heal})

      result = play_card(updated_combat, {0, 0, 0})

      {:ok, result: result, heal_card: @cards.heal, original_hp: fighter.hp}
    end

    test "increases target HP by heal amount", %{
      result: {:ok, updated_combat},
      original_hp: original_hp,
      heal_card: heal_card
    } do
      updated_fighter = updated_combat.current_turn.player
      [%{"type" => "heal", "value" => heal_amount}] = heal_card.effects
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
      # Adjacent empty tile with a clear path
      target_position = {0, -1, 1}
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
    setup %{combat_state: combat_state, fighter: fighter, mage: _mage} do
      # Place target at distance 3, out of range for attack card (range 1)
      {:ok, updated_combat} =
        Combat.process_action(combat_state, {:pick_card, fighter, @cards.attack})

      result = play_card(updated_combat, {3, 0, -3})

      {:ok, result: result}
    end

    test "returns error when target is out of range", %{result: result} do
      assert {:error, _} = result
    end
  end

  describe "game over check" do
    setup %{combat_state: combat_state, fighter: fighter, mage: mage} do
      {:ok, updated_combat} =
        Combat.process_action(combat_state, {:pick_card, fighter, @cards.lethal})

      result = play_card(updated_combat, mage.position)

      {:ok, result: result}
    end

    test "game state changes to game_over when character is killed", %{
      result: {:ok, updated_combat}
    } do
      assert updated_combat.state == :game_over
    end

    test "dead character is removed from players list", %{result: {:ok, updated_combat}} do
      # Queue only contains waiting players, not current player
      # After mage dies, only fighter remains (as current player), so queue is empty
      assert length(updated_combat.queue) == 0
    end

    test "dead character is removed from queue", %{result: {:ok, updated_combat}} do
      # Queue only contains waiting players, not current player
      # After mage dies, only fighter remains (as current player), so queue is empty
      assert length(updated_combat.queue) == 0
    end
  end

  describe "move back and forth between tiles" do
    setup %{combat_state: combat_state, fighter: fighter} do
      start_position = fighter.position
      # distance 1 — fighter can reach it and has 1 movement left to come back
      target_position = {0, -1, 1}

      {:ok, first_move_result} =
        Combat.process_action(combat_state, {:move, fighter, target_position})

      result =
        Combat.process_action(
          first_move_result,
          {:move, first_move_result.current_turn.player, start_position}
        )

      {:ok,
       result: result,
       start_position: start_position,
       target_position: target_position,
       first_move_result: first_move_result}
    end

    test "first move succeeds", %{first_move_result: first_move_result} do
      assert first_move_result.current_turn.player != nil
    end

    test "first move updates fighter position to target", %{
      first_move_result: first_move_result,
      target_position: target_position
    } do
      assert first_move_result.current_turn.player.position == target_position
    end

    test "first move deducts 1 from movement budget (range 2, moved 1 tile)", %{
      first_move_result: first_move_result
    } do
      assert first_move_result.current_turn.movement_remaining == 1
    end

    test "second move back succeeds with remaining budget", %{result: result} do
      assert {:ok, _} = result
    end
  end

  describe "multi-step movement within budget" do
    setup %{combat_state: combat_state, fighter: fighter} do
      # Fighter with range 3: step 1 to {0,-1,1}, step 2 to {1,-1,0}
      fighter_3 = %{fighter | movement_range: 3, position: {0, 0, 0}}

      combat_with_fighter3 = %{
        combat_state
        | current_turn: %{combat_state.current_turn | player: fighter_3}
      }

      step1_target = {0, -1, 1}

      {:ok, after_step1} =
        Combat.process_action(combat_with_fighter3, {:move, fighter_3, step1_target})

      step2_target = {1, -1, 0}

      result =
        Combat.process_action(
          after_step1,
          {:move, after_step1.current_turn.player, step2_target}
        )

      {:ok,
       result: result,
       after_step1: after_step1,
       step1_target: step1_target,
       step2_target: step2_target}
    end

    test "first step succeeds and deducts budget", %{after_step1: after_step1} do
      assert after_step1.current_turn.movement_remaining == 2
    end

    test "second step succeeds with remaining budget", %{result: result} do
      assert {:ok, _} = result
    end

    test "second step deducts from remaining budget", %{result: {:ok, updated_combat}} do
      assert updated_combat.current_turn.movement_remaining == 1
    end

    test "player ends at second target position", %{
      result: {:ok, updated_combat},
      step2_target: step2_target
    } do
      assert updated_combat.current_turn.player.position == step2_target
    end
  end

  describe "consecutive attacks on same target" do
    setup do
      # Initialize a mage and a fighter from fixtures
      mage = Fixtures.mage()
      fighter = Fixtures.fighter()

      # Create two identical attack cards for the fighter with sufficient range
      attack_card1 = %{
        Fixtures.attack_card()
        | id: 1,
          effects: [%{"type" => "damage", "value" => 5}],
          range: 2
      }

      attack_card2 = %{
        Fixtures.attack_card()
        | id: 2,
          effects: [%{"type" => "damage", "value" => 5}],
          range: 2
      }

      # Set positions for both characters
      fighter = %{fighter | position: {1, 0, -1}}
      mage = %{mage | hp: 20, position: {2, -1, -1}}

      # Prepare fighter with two attack cards in hand
      fighter = %{fighter | cards: %{fighter.cards | hand: [attack_card1, attack_card2]}}

      # Create a small grid with fighter and mage positioned for attack
      grid = %Grid{
        tiles: %{
          {1, 0, -1} => %{terrain: :plain, occupied_by: fighter},
          {2, -1, -1} => %{terrain: :plain, occupied_by: mage}
        }
      }

      # Create the combat state with fighter's turn first
      combat_state = %CombatState{
        state: :running,
        __constants__: %{
          players: [fighter, mage]
        },
        queue: [mage],
        grid: grid,
        current_turn: %{
          starting_position: {1, 0, -1},
          player: fighter,
          card: nil
        }
      }

      {:ok,
       combat_state: combat_state,
       fighter: fighter,
       mage: mage,
       attack_card1: attack_card1,
       attack_card2: attack_card2}
    end

    test "fighter can play two attack cards consecutively on the same target", %{
      combat_state: combat_state,
      fighter: fighter,
      mage: mage,
      attack_card1: attack_card1,
      attack_card2: attack_card2
    } do
      # First attack - Pick the first card
      {:ok, card_selected_combat} =
        Combat.process_action(combat_state, {:pick_card, fighter, attack_card1})

      # Play the card on mage's position
      {:ok, first_attack_result} =
        play_card(card_selected_combat, mage.position)

      # Find updated mage after first attack
      updated_mage = Enum.find(first_attack_result.queue, &(&1.id == mage.id))

      # Verify mage took damage from first attack
      assert updated_mage.hp == mage.hp - 5

      # Find updated fighter after first attack
      updated_fighter = first_attack_result.current_turn.player

      # Verify the first attack card is no longer in fighter's hand
      refute Enum.any?(updated_fighter.cards.hand, fn c -> c.id == attack_card1.id end)

      # Verify the first attack card is now in fighter's discard
      assert Enum.any?(updated_fighter.cards.discard, fn c -> c.id == attack_card1.id end)

      # Second attack - Pick the second card
      {:ok, second_card_selected} =
        Combat.process_action(first_attack_result, {:pick_card, updated_fighter, attack_card2})

      # Play the second card on mage's position
      {:ok, second_attack_result} =
        play_card(second_card_selected, mage.position)

      # Find updated mage after second attack
      final_mage = Enum.find(second_attack_result.queue, &(&1.id == mage.id))

      # Verify mage took damage from second attack (10 total damage)
      assert final_mage.hp == mage.hp - 10

      # Find updated fighter after second attack
      final_fighter = second_attack_result.current_turn.player

      # Verify the second attack card is no longer in fighter's hand
      refute Enum.any?(final_fighter.cards.hand, fn c -> c.id == attack_card2.id end)

      # Verify the second attack card is now in fighter's discard
      assert Enum.any?(final_fighter.cards.discard, fn c -> c.id == attack_card2.id end)

      # Verify both cards are in discard pile
      assert Enum.count(final_fighter.cards.discard) == 2

      # Verify the game is still running after both attacks
      assert second_attack_result.state == :running
    end
  end

  describe "play_card with unimplemented effect" do
    setup %{combat_state: combat_state, fighter: fighter, mage: mage} do
      # Create a card with both implemented (damage) and unimplemented (poison) effects
      mixed_card = %{
        Fixtures.attack_card()
        | id: 100,
          effects: [
            %{"type" => "damage", "value" => 3},
            %{"type" => "poison", "value" => 2},
            %{"type" => "unimplemented_effect", "value" => 5}
          ]
      }

      # Add card to fighter's hand
      fighter_with_card = %{fighter | cards: %{fighter.cards | hand: [mixed_card]}}

      combat_state = %{
        combat_state
        | current_turn: %{combat_state.current_turn | player: fighter_with_card}
      }

      {:ok,
       combat_state: combat_state, fighter: fighter_with_card, mage: mage, mixed_card: mixed_card}
    end

    test "card plays successfully and ignores unimplemented effects", %{
      combat_state: combat_state,
      fighter: fighter,
      mage: mage,
      mixed_card: mixed_card
    } do
      # Pick the card with mixed effects
      {:ok, updated_combat} =
        Combat.process_action(combat_state, {:pick_card, fighter, mixed_card})

      # Play the card on the mage
      result = play_card(updated_combat, mage.position)

      # Should succeed despite unimplemented effects
      assert {:ok, _final_combat} = result
    end

    test "implemented effects are applied correctly", %{
      combat_state: combat_state,
      fighter: fighter,
      mage: mage,
      mixed_card: mixed_card
    } do
      original_mage_hp = mage.hp

      # Pick and play the card
      {:ok, updated_combat} =
        Combat.process_action(combat_state, {:pick_card, fighter, mixed_card})

      {:ok, final_combat} = play_card(updated_combat, mage.position)

      # Get updated mage
      updated_mage = Enum.find(final_combat.queue, &(&1.id == mage.id))

      # Damage effect should be applied (3 damage)
      assert updated_mage.hp == original_mage_hp - 3
    end

    test "unimplemented effects do not cause errors", %{
      combat_state: combat_state,
      fighter: fighter,
      mage: mage,
      mixed_card: mixed_card
    } do
      # Pick and play the card
      {:ok, updated_combat} =
        Combat.process_action(combat_state, {:pick_card, fighter, mixed_card})

      result = play_card(updated_combat, mage.position)

      # Should not return an error
      refute match?({:error, _}, result)
      assert match?({:ok, _}, result)
    end

    test "card is moved to discard pile after playing", %{
      combat_state: combat_state,
      fighter: fighter,
      mage: mage,
      mixed_card: mixed_card
    } do
      # Pick and play the card
      {:ok, updated_combat} =
        Combat.process_action(combat_state, {:pick_card, fighter, mixed_card})

      {:ok, final_combat} = play_card(updated_combat, mage.position)

      updated_fighter = final_combat.current_turn.player

      # Card should be in discard pile
      assert Enum.any?(updated_fighter.cards.discard, fn c -> c.id == mixed_card.id end)

      # Card should not be in hand
      refute Enum.any?(updated_fighter.cards.hand, fn c -> c.id == mixed_card.id end)
    end
  end

  describe "movement cannot pass through walls" do
    # Fighter at {0,0,0}. A 5-tile wall spans the diagonal strip:
    #   {-2,1,1}, {-1,1,0}, {0,1,-1}, {1,0,-1}, {2,-1,-1}
    # Target {0,2,-2} sits behind the wall; the only walkable detour goes:
    #   {0,0,0} → {1,0,-1}... wait, that's walled.
    # Detour: {0,0,0} → {1,-1,0} → {2,-1,-1}... also walled.
    # Actually detour goes the other way:
    #   {0,0,0} → {-1,0,1} → {-2,1,1}... walled.
    # The wall fully severs the grid — {0,2,-2} is unreachable regardless of movement.
    # For the "enough movement via detour" test, we use a partial wall (4 tiles)
    # leaving one gap, with a target that needs exactly 4 steps to reach.
    setup do
      fighter = %{Fixtures.fighter() | position: {0, 0, 0}}
      # Use a radius-4 grid so there's room for detours
      grid = Game.Grid.new({4, 4, 4})

      # 5-tile wall that fully severs the grid between fighter and {0,2,-2}
      full_wall = [{-2, 1, 1}, {-1, 1, 0}, {0, 1, -1}, {1, 0, -1}, {2, -1, -1}]

      grid_full_wall =
        Enum.reduce(full_wall, grid, fn pos, g ->
          put_in(g.tiles[pos].terrain, :wall)
        end)

      grid_full_wall = Game.Grid.update_character(grid_full_wall, fighter)

      # Partial wall (4 tiles) — gap at {-2,1,1} — detour path to {0,2,-2} is 4 steps:
      #   {0,0,0}→{-1,0,1}→{-2,1,1}→{-1,2,-1}→{0,2,-2}
      partial_wall = [{-1, 1, 0}, {0, 1, -1}, {1, 0, -1}, {2, -1, -1}]

      grid_partial_wall =
        Enum.reduce(partial_wall, grid, fn pos, g ->
          put_in(g.tiles[pos].terrain, :wall)
        end)

      grid_partial_wall = Game.Grid.update_character(grid_partial_wall, fighter)

      make_combat = fn g ->
        %CombatState{
          state: :running,
          __constants__: %{players: [fighter]},
          queue: [fighter],
          grid: g,
          current_turn: %{
            player: fighter,
            starting_position: fighter.position,
            movement_remaining: nil,
            card: nil
          }
        }
      end

      {:ok,
       fighter: fighter,
       combat_full_wall: make_combat.(grid_full_wall),
       combat_partial_wall: make_combat.(grid_partial_wall)}
    end

    test "rejects move to tile behind full wall even when within hex distance", %{
      combat_full_wall: combat,
      fighter: fighter
    } do
      target = {0, 2, -2}
      # hex distance is 2 — within default movement range — but no path exists
      assert Grid.distance(combat.grid, fighter.position, target) == 2
      assert {:error, _} = Combat.process_action(combat, {:move, fighter, target})
    end

    test "rejects move via detour when movement budget is insufficient", %{
      combat_partial_wall: combat,
      fighter: fighter
    } do
      # detour path is 5 steps; fighter movement_range is 2
      target = {0, 2, -2}
      assert fighter.movement_range < 5
      assert {:error, _} = Combat.process_action(combat, {:move, fighter, target})
    end

    test "allows move via detour when movement budget is sufficient", %{
      combat_partial_wall: combat,
      fighter: fighter
    } do
      # same target, give the fighter enough movement to take the 5-step detour
      fighter_5 = %{fighter | movement_range: 5}

      combat =
        put_in(combat, [:current_turn, :player], fighter_5)
        |> put_in([:__constants__, :players], [fighter_5])

      target = {0, 2, -2}
      assert {:ok, result} = Combat.process_action(combat, {:move, fighter_5, target})
      assert result.current_turn.player.position == target
    end
  end

  describe "current player dying on their own turn" do
    # Three players across two teams: fighter (team1) suicides.
    # mage (team2) and ally (team1) survive — two teams still alive so game stays :running.
    # The turn must advance to the next queued player (mage), not leave player nil.
    setup do
      fighter = Fixtures.fighter()
      mage = Fixtures.mage()
      ally = %{Fixtures.fighter() | id: 3, name: "Ally", position: {2, 0, -2}}

      # Card that deals exactly the fighter's max HP — lethal on self
      suicide_card = %{Fixtures.lethal_card() | id: 99, range: 1}
      fighter = %{fighter | cards: %{fighter.cards | hand: [suicide_card]}}

      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: fighter},
          {1, 0, -1} => %{terrain: :plain, occupied_by: mage},
          {2, 0, -2} => %{terrain: :plain, occupied_by: ally}
        }
      }

      combat = %CombatState{
        state: :card_selected,
        __constants__: %{players: [fighter, mage, ally]},
        queue: [mage, ally],
        grid: grid,
        current_turn: %{
          starting_position: fighter.position,
          player: fighter,
          card: suicide_card
        }
      }

      {:ok, combat: combat, fighter: fighter, mage: mage, ally: ally}
    end

    test "turn advances to the next character instead of leaving player nil", %{
      combat: combat,
      mage: mage
    } do
      {:ok, result, _animations} =
        Combat.process_action(combat, {:play_card_on_character, combat.current_turn.player})

      assert result.current_turn.player != nil
      assert result.current_turn.player.id == mage.id
    end

    test "dead fighter is moved to dead_characters", %{combat: combat, fighter: fighter} do
      {:ok, result, _animations} =
        Combat.process_action(combat, {:play_card_on_character, combat.current_turn.player})

      assert Enum.any?(result.dead_characters, &(&1.id == fighter.id))
    end

    test "game state remains :running when both teams still have survivors", %{combat: combat} do
      {:ok, result, _animations} =
        Combat.process_action(combat, {:play_card_on_character, combat.current_turn.player})

      assert result.state == :running
    end
  end
end
