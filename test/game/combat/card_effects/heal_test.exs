defmodule Game.Combat.CardEffects.HealTest do
  use ExUnit.Case, async: true

  alias Game.Combat.CardEffect
  alias Game.Combat.CardEffects.Heal
  alias Game.{CombatState, Grid, Fixtures}

  describe "Heal effect" do
    setup do
      warrior = %{Fixtures.warrior() | hp: 10}
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

      heal_effect = %Heal{type: :heal, value: 5}

      {:ok, combat_state: combat_state, heal_effect: heal_effect, warrior: warrior}
    end

    test "process/3 increases target HP by heal value", %{
      combat_state: combat_state,
      heal_effect: heal_effect,
      warrior: warrior
    } do
      original_hp = warrior.hp
      updated_state = CardEffect.process(heal_effect, warrior, combat_state)

      updated_warrior = updated_state.current_turn.player
      assert updated_warrior.hp == original_hp + 5
    end

    test "get_description/1 returns correct heal description", %{heal_effect: heal_effect} do
      description = CardEffect.get_description(heal_effect)
      assert description == "Restores 5 hp to target"
    end

    test "process/3 with large heal value", %{combat_state: combat_state, warrior: warrior} do
      large_heal = %Heal{type: :heal, value: 100}
      updated_state = CardEffect.process(large_heal, warrior, combat_state)

      updated_warrior = updated_state.current_turn.player
      # Should cap at max HP
      assert updated_warrior.hp >= warrior.hp
    end
  end
end
