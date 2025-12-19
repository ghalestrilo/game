defmodule Game.Combat.CardEffects.DamageTest do
  use ExUnit.Case, async: true

  alias Game.Combat.CardEffect
  alias Game.Combat.CardEffects.Damage
  alias Game.{CombatState, Grid, Fixtures}

  describe "Damage effect" do
    setup do
      warrior = Fixtures.warrior()
      mage = %{Fixtures.mage() | hp: 15, position: {1, 0, -1}}

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

      damage_effect = %Damage{type: :damage, value: 5}

      {:ok, combat_state: combat_state, damage_effect: damage_effect, mage: mage}
    end

    test "process/3 reduces target HP by damage value", %{
      combat_state: combat_state,
      damage_effect: damage_effect,
      mage: mage
    } do
      original_hp = mage.hp
      updated_state = CardEffect.process(damage_effect, mage, combat_state)

      updated_mage = Enum.find(updated_state.queue, &(&1.id == mage.id))
      assert updated_mage.hp == original_hp - 5
    end

    test "get_description/1 returns correct damage description", %{damage_effect: damage_effect} do
      description = CardEffect.get_description(damage_effect)
      assert description == "Deal 5 damage to target"
    end

    test "process/3 with large damage value", %{combat_state: combat_state, mage: mage} do
      large_damage = %Damage{type: :damage, value: 20}
      updated_state = CardEffect.process(large_damage, mage, combat_state)

      updated_mage = Enum.find(updated_state.queue, &(&1.id == mage.id))
      assert updated_mage.hp <= 0
    end
  end
end
