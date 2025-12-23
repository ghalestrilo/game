defmodule Game.Combat.CardEffects.ShieldTest do
  use ExUnit.Case, async: true

  alias Game.Combat.CardEffect
  alias Game.Combat.CardEffects.Shield
  alias Game.{Character, CombatState, Grid, Fixtures}

  describe "Shield effect" do
    setup do
      warrior = Fixtures.fighter()
      mage = Fixtures.mage()

      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: warrior},
          {1, 0, -1} => %{terrain: :plain, occupied_by: mage}
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

      shield_effect = %Shield{type: :shield, value: 5}

      {:ok, combat_state: combat_state, shield_effect: shield_effect, warrior: warrior}
    end

    test "process/3 adds shield status effect to target", %{
      combat_state: combat_state,
      shield_effect: shield_effect,
      warrior: warrior
    } do
      updated_state = CardEffect.process(shield_effect, warrior, combat_state)
      updated_warrior = updated_state.current_turn.player

      shield_status = Character.get_status_effect(updated_warrior, :shield)
      assert shield_status != nil
      assert shield_status.type == :shield
      assert shield_status.value == 5
    end

    test "get_description/1 returns correct shield description", %{shield_effect: shield_effect} do
      description = CardEffect.get_description(shield_effect)
      assert description == "Grant 5 shield to target"
    end

    test "process/3 with large shield value", %{combat_state: combat_state, warrior: warrior} do
      large_shield = %Shield{type: :shield, value: 20}
      updated_state = CardEffect.process(large_shield, warrior, combat_state)
      updated_warrior = updated_state.current_turn.player

      shield_status = Character.get_status_effect(updated_warrior, :shield)
      assert shield_status.value == 20
    end
  end
end
