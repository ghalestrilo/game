defmodule Game.Combat.CardEffects.CleanseTest do
  use ExUnit.Case, async: true

  alias Game.Combat.CardEffect
  alias Game.Combat.CardEffects.Cleanse
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

  describe "process/3 removes negative effects" do
    test "removes :stuck", %{combat: combat, mage: mage} do
      afflicted = Character.add_status_effect(mage, %{type: :stuck, value: 2})
      combat = %{combat | queue: [afflicted]}
      updated = CardEffect.process(%Cleanse{}, afflicted, combat)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert Character.get_status_effect(updated_mage, :stuck) == nil
    end

    test "removes :slow", %{combat: combat, mage: mage} do
      afflicted = Character.add_status_effect(mage, %{type: :slow, value: 1, duration: 3})
      combat = %{combat | queue: [afflicted]}
      updated = CardEffect.process(%Cleanse{}, afflicted, combat)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert Character.get_status_effect(updated_mage, :slow) == nil
    end

    test "removes :stun", %{combat: combat, mage: mage} do
      afflicted = Character.add_status_effect(mage, %{type: :stun, value: 2})
      combat = %{combat | queue: [afflicted]}
      updated = CardEffect.process(%Cleanse{}, afflicted, combat)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert Character.get_status_effect(updated_mage, :stun) == nil
    end

    test "removes :dot", %{combat: combat, mage: mage} do
      afflicted = Character.add_status_effect(mage, %{type: :dot, damage: 5, value: 3})
      combat = %{combat | queue: [afflicted]}
      updated = CardEffect.process(%Cleanse{}, afflicted, combat)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert Character.get_status_effect(updated_mage, :dot) == nil
    end

    test "removes multiple negative effects at once", %{combat: combat, mage: mage} do
      afflicted =
        mage
        |> Character.add_status_effect(%{type: :stuck, value: 1})
        |> Character.add_status_effect(%{type: :stun, value: 2})
        |> Character.add_status_effect(%{type: :dot, damage: 3, value: 2})

      combat = %{combat | queue: [afflicted]}
      updated = CardEffect.process(%Cleanse{}, afflicted, combat)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert updated_mage.status_effects == []
    end
  end

  describe "process/3 preserves positive effects" do
    test "does not remove :shield", %{combat: combat, mage: mage} do
      buffed = Character.add_status_effect(mage, %{type: :shield, value: 10})
      combat = %{combat | queue: [buffed]}
      updated = CardEffect.process(%Cleanse{}, buffed, combat)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert Character.get_status_effect(updated_mage, :shield) != nil
    end

    test "does not remove :stealth", %{combat: combat, mage: mage} do
      buffed = Character.add_status_effect(mage, %{type: :stealth, value: 2})
      combat = %{combat | queue: [buffed]}
      updated = CardEffect.process(%Cleanse{}, buffed, combat)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert Character.get_status_effect(updated_mage, :stealth) != nil
    end

    test "does not remove :regen", %{combat: combat, mage: mage} do
      buffed = Character.add_status_effect(mage, %{type: :regen, heal: 3, value: 2})
      combat = %{combat | queue: [buffed]}
      updated = CardEffect.process(%Cleanse{}, buffed, combat)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert Character.get_status_effect(updated_mage, :regen) != nil
    end

    test "does not remove :ethereal", %{combat: combat, mage: mage} do
      buffed = Character.add_status_effect(mage, %{type: :ethereal, value: 2})
      combat = %{combat | queue: [buffed]}
      updated = CardEffect.process(%Cleanse{}, buffed, combat)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert Character.get_status_effect(updated_mage, :ethereal) != nil
    end

    test "is a no-op when no negative effects present", %{combat: combat, mage: mage} do
      updated = CardEffect.process(%Cleanse{}, mage, combat)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert updated_mage.status_effects == []
    end
  end

  describe "protocol contracts" do
    test "get_description/1" do
      assert is_binary(CardEffect.get_description(%Cleanse{}))
    end

    test "get_icon/1 returns a string" do
      assert is_binary(CardEffect.get_icon(%Cleanse{}))
    end

    test "get_value_label/1 returns a string" do
      assert is_binary(CardEffect.get_value_label(%Cleanse{}))
    end

    test "animate/1 returns label and color" do
      assert %{label: _, color: _} = CardEffect.animate(%Cleanse{})
    end
  end
end
