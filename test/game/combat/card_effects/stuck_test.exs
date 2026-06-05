defmodule Game.Combat.CardEffects.StuckTest do
  use ExUnit.Case, async: true

  alias Game.Combat.CardEffect
  alias Game.Combat.CardEffects.Stuck
  alias Game.{Character, CombatState, Grid, Fixtures}

  setup do
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
    test "adds stuck status effect to target", %{combat: combat, mage: mage} do
      updated = CardEffect.process(%Stuck{value: 2}, mage, combat)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      stuck = Character.get_status_effect(updated_mage, :stuck)
      assert stuck != nil
      assert stuck.value == 2
    end

    test "adds stuck status to current player when self-targeting", %{
      combat: combat,
      fighter: fighter
    } do
      updated = CardEffect.process(%Stuck{value: 1}, fighter, combat)
      stuck = Character.get_status_effect(updated.current_turn.player, :stuck)
      assert stuck != nil
      assert stuck.value == 1
    end
  end

  describe "move blocked by stuck" do
    test "stuck character cannot move even with movement_range > 0", %{
      combat: combat,
      fighter: fighter
    } do
      stuck_fighter = Character.add_status_effect(fighter, %{type: :stuck, value: 1})
      combat = %{combat | current_turn: %{combat.current_turn | player: stuck_fighter}}

      result = Game.Combat.process_action(combat, {:move, stuck_fighter, {2, 0, -2}})
      assert {:error, _} = result
    end

    test "unstuck character can move normally", %{combat: combat, fighter: fighter} do
      # Add an adjacent tile the fighter can reach directly
      grid = %{
        combat.grid
        | tiles: Map.put(combat.grid.tiles, {0, -1, 1}, %{terrain: :plain, occupied_by: nil})
      }

      combat = %{combat | grid: grid}

      result = Game.Combat.process_action(combat, {:move, fighter, {0, -1, 1}})
      assert {:ok, _} = result
    end
  end

  describe "stuck countdown via setup_player_turn" do
    test "stuck ticks down by 1 on the stuck player's own turn", %{
      combat: combat,
      fighter: fighter
    } do
      stuck_fighter = Character.add_status_effect(fighter, %{type: :stuck, value: 2})
      combat = %{combat | current_turn: %{combat.current_turn | player: stuck_fighter}}

      # Rotate to mage, then back to fighter
      next = combat |> CombatState.rotate_queue() |> CombatState.setup_player_turn()
      next = next |> CombatState.rotate_queue() |> CombatState.setup_player_turn()

      stuck = Character.get_status_effect(next.current_turn.player, :stuck)
      assert stuck.value == 1
    end

    test "stuck is removed when it reaches 0", %{combat: combat, fighter: fighter} do
      stuck_fighter = Character.add_status_effect(fighter, %{type: :stuck, value: 1})
      combat = %{combat | current_turn: %{combat.current_turn | player: stuck_fighter}}

      next = combat |> CombatState.rotate_queue() |> CombatState.setup_player_turn()
      next = next |> CombatState.rotate_queue() |> CombatState.setup_player_turn()

      assert Character.get_status_effect(next.current_turn.player, :stuck) == nil
    end
  end

  describe "protocol contracts" do
    test "get_description/1" do
      assert CardEffect.get_description(%Stuck{value: 2}) =~ "stuck"
    end

    test "get_icon/1 returns a string" do
      assert is_binary(CardEffect.get_icon(%Stuck{}))
    end

    test "get_value_label/1 returns a string" do
      assert is_binary(CardEffect.get_value_label(%Stuck{value: 2}))
    end

    test "animate/1 returns label and color" do
      anim = CardEffect.animate(%Stuck{})
      assert %{label: _, color: _} = anim
    end
  end
end
