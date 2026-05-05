defmodule Game.Combat.CardEffects.RegenTest do
  use ExUnit.Case, async: true

  alias Game.Combat.CardEffect
  alias Game.Combat.CardEffects.Regen
  alias Game.{Character, CombatState, Grid, Fixtures}

  setup do
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
      current_turn: %{
        starting_position: fighter.position,
        player: fighter,
        card: nil
      }
    }

    {:ok, combat: combat, fighter: fighter, mage: mage}
  end

  describe "process/3" do
    test "adds regen status effect with heal and duration", %{combat: combat, mage: mage} do
      updated = CardEffect.process(%Regen{value: 3, heal: 5}, mage, combat)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      regen = Character.get_status_effect(updated_mage, :regen)
      assert regen != nil
      assert regen.heal == 5
      assert regen.value == 3
    end
  end

  describe "regen healing via setup_player_turn" do
    test "regen heals at the start of the affected player's turn", %{
      combat: combat,
      mage: mage
    } do
      damaged_mage = %{mage | hp: 10}
      regen_mage = Character.add_status_effect(damaged_mage, %{type: :regen, heal: 4, value: 2})
      combat = %{combat | queue: [regen_mage]}

      next =
        combat
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()

      assert next.current_turn.player.hp == 14
    end

    test "regen does not exceed max_hp", %{combat: combat, mage: mage} do
      # mage max_hp: 15, current hp: 14
      almost_full_mage = %{mage | hp: 14, max_hp: 15}
      regen_mage = Character.add_status_effect(almost_full_mage, %{type: :regen, heal: 5, value: 1})
      combat = %{combat | queue: [regen_mage]}

      next =
        combat
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()

      assert next.current_turn.player.hp == 15
    end

    test "regen fires on the last tick (value: 1) then is removed", %{
      combat: combat,
      mage: mage
    } do
      damaged_mage = %{mage | hp: 10}
      regen_mage = Character.add_status_effect(damaged_mage, %{type: :regen, heal: 3, value: 1})
      combat = %{combat | queue: [regen_mage]}

      next =
        combat
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()

      assert next.current_turn.player.hp == 13
      assert Character.get_status_effect(next.current_turn.player, :regen) == nil
    end

    test "regen fires n times over n turns", %{combat: combat, mage: mage} do
      damaged_mage = %{mage | hp: 5}
      regen_mage = Character.add_status_effect(damaged_mage, %{type: :regen, heal: 2, value: 2})
      combat = %{combat | queue: [regen_mage]}

      after_turn1 =
        combat
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()

      assert after_turn1.current_turn.player.hp == 7

      after_fighter =
        after_turn1
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()

      after_turn2 =
        after_fighter
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()

      assert after_turn2.current_turn.player.id == mage.id
      assert after_turn2.current_turn.player.hp == 9
      assert Character.get_status_effect(after_turn2.current_turn.player, :regen) == nil
    end
  end

  describe "protocol contracts" do
    test "get_description/1" do
      assert is_binary(CardEffect.get_description(%Regen{value: 2, heal: 3}))
    end

    test "get_icon/1 returns a string" do
      assert is_binary(CardEffect.get_icon(%Regen{}))
    end

    test "get_value_label/1 returns a string" do
      assert is_binary(CardEffect.get_value_label(%Regen{value: 2, heal: 3}))
    end

    test "animate/1 returns label and color" do
      assert %{label: _, color: _} = CardEffect.animate(%Regen{heal: 3})
    end
  end
end
