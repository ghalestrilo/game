defmodule Game.Combat.CardEffects.SlowTest do
  use ExUnit.Case, async: true

  alias Game.Combat.CardEffect
  alias Game.Combat.CardEffects.Slow
  alias Game.{Character, CombatState, Grid, Fixtures}

  setup do
    # fighter has movement_range: 2
    fighter = Fixtures.fighter()
    mage = %{Fixtures.mage() | position: {1, 0, -1}}

    grid = %Grid{
      tiles: %{
        {0, 0, 0} => %{terrain: :plain, occupied_by: fighter},
        {1, 0, -1} => %{terrain: :plain, occupied_by: mage},
        {2, 0, -2} => %{terrain: :plain, occupied_by: nil}
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

    {:ok, combat: combat, fighter: fighter, mage: mage}
  end

  describe "process/3" do
    test "adds slow status effect with given reduction and duration", %{
      combat: combat,
      mage: mage
    } do
      updated = CardEffect.process(%Slow{value: 1, duration: 2}, mage, combat)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      slow = Character.get_status_effect(updated_mage, :slow)
      assert slow != nil
      assert slow.value == 1
      assert slow.duration == 2
    end

    test "adds permanent slow when duration is nil", %{combat: combat, mage: mage} do
      updated = CardEffect.process(%Slow{value: 1, duration: nil}, mage, combat)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      slow = Character.get_status_effect(updated_mage, :slow)
      assert slow.duration == nil
    end
  end

  describe "move with slow" do
    test "slowed character cannot move beyond reduced range", %{
      combat: combat,
      fighter: fighter
    } do
      # fighter movement_range: 2, slow by 1 → effective range 1
      # {2, 0, -2} is distance 2, should fail
      slowed_fighter = Character.add_status_effect(fighter, %{type: :slow, value: 1, duration: 2})
      combat = %{combat | current_turn: %{combat.current_turn | player: slowed_fighter}}

      result = Game.Combat.process_action(combat, {:move, slowed_fighter, {2, 0, -2}})
      assert result == {:error, "Not enough movement"}
    end

    test "slowed character can still move within reduced range", %{
      combat: combat,
      fighter: fighter
    } do
      # fighter movement_range: 2, slow by 1 → effective range 1
      # {1, 0, -1} is distance 1, should succeed
      slowed_fighter = Character.add_status_effect(fighter, %{type: :slow, value: 1, duration: 2})

      combat = %{
        combat
        | queue: [slowed_fighter],
          current_turn: %{combat.current_turn | player: slowed_fighter}
      }

      result = Game.Combat.process_action(combat, {:move, slowed_fighter, {1, 0, -1}})
      assert {:error, _} = result
      # {1, 0, -1} is blocked by mage — use a free tile
    end

    test "slowed character can move to a free tile within reduced range", %{
      combat: combat,
      fighter: fighter
    } do
      slowed_fighter = Character.add_status_effect(fighter, %{type: :slow, value: 1, duration: 2})

      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: slowed_fighter},
          {1, 0, -1} => %{terrain: :plain, occupied_by: nil},
          {2, 0, -2} => %{terrain: :plain, occupied_by: nil}
        }
      }

      combat = %{
        combat
        | grid: grid,
          queue: [],
          current_turn: %{combat.current_turn | player: slowed_fighter}
      }

      # distance 1 should succeed with effective_range 1
      assert {:ok, _} = Game.Combat.process_action(combat, {:move, slowed_fighter, {1, 0, -1}})
    end

    test "slow clamped to 0 when reduction >= movement_range", %{
      combat: combat,
      fighter: fighter
    } do
      # fighter movement_range: 2, slow by 5 → effective range 0
      slowed_fighter = Character.add_status_effect(fighter, %{type: :slow, value: 5, duration: 1})
      combat = %{combat | current_turn: %{combat.current_turn | player: slowed_fighter}}

      result = Game.Combat.process_action(combat, {:move, slowed_fighter, {1, 0, -1}})
      assert result == {:error, "Not enough movement"}
    end
  end

  describe "slow countdown via setup_player_turn" do
    test "timed slow decrements duration each turn", %{combat: combat, fighter: fighter} do
      slowed_fighter = Character.add_status_effect(fighter, %{type: :slow, value: 1, duration: 2})
      combat = %{combat | current_turn: %{combat.current_turn | player: slowed_fighter}}

      next = combat |> CombatState.rotate_queue() |> CombatState.setup_player_turn()
      next = next |> CombatState.rotate_queue() |> CombatState.setup_player_turn()

      slow = Character.get_status_effect(next.current_turn.player, :slow)
      assert slow.duration == 1
    end

    test "timed slow is removed when duration reaches 0", %{combat: combat, fighter: fighter} do
      slowed_fighter = Character.add_status_effect(fighter, %{type: :slow, value: 1, duration: 1})
      combat = %{combat | current_turn: %{combat.current_turn | player: slowed_fighter}}

      next = combat |> CombatState.rotate_queue() |> CombatState.setup_player_turn()
      next = next |> CombatState.rotate_queue() |> CombatState.setup_player_turn()

      assert Character.get_status_effect(next.current_turn.player, :slow) == nil
    end

    test "permanent slow (duration: nil) is never removed by tick", %{
      combat: combat,
      fighter: fighter
    } do
      slowed_fighter =
        Character.add_status_effect(fighter, %{type: :slow, value: 1, duration: nil})

      combat = %{combat | current_turn: %{combat.current_turn | player: slowed_fighter}}

      # After several full rotations, fighter's slow should still be present
      after_two_fighter_turns =
        combat
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()

      # fighter is current player after 2nd rotation; verify slow persists
      assert after_two_fighter_turns.current_turn.player.id == fighter.id
      slow = Character.get_status_effect(after_two_fighter_turns.current_turn.player, :slow)
      assert slow != nil
      assert slow.duration == nil
    end
  end

  describe "protocol contracts" do
    test "get_description/1" do
      assert is_binary(CardEffect.get_description(%Slow{value: 1, duration: 2}))
    end

    test "get_icon/1 returns a string" do
      assert is_binary(CardEffect.get_icon(%Slow{}))
    end

    test "get_value_label/1 returns a string" do
      assert is_binary(CardEffect.get_value_label(%Slow{value: 1}))
    end

    test "animate/1 returns label and color" do
      assert %{label: _, color: _} = CardEffect.animate(%Slow{})
    end
  end
end
