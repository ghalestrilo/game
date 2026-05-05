defmodule Game.Combat.CardEffects.HexTest do
  use ExUnit.Case, async: true

  alias Game.Combat.CardEffect
  alias Game.Combat.CardEffects.Hex
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
      current_turn: %{starting_position: fighter.position, player: fighter, card: nil}
    }

    {:ok, combat: combat, fighter: fighter, mage: mage}
  end

  describe "process/3" do
    test "adds hex status effect to target", %{combat: combat, mage: mage} do
      updated = CardEffect.process(%Hex{value: 2}, mage, combat)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      hex = Character.get_status_effect(updated_mage, :hex)
      assert hex != nil
      assert hex.value == 2
    end
  end

  describe "hex inverts damage" do
    test "damage heals a hexed character", %{mage: mage} do
      hexed_mage = Character.add_status_effect(mage, %{type: :hex, value: 2})
      original_hp = hexed_mage.hp

      updated = Character.apply_damage(hexed_mage, 5)
      assert updated.hp == original_hp + 5
    end

    test "healing damages a hexed character", %{mage: mage} do
      hexed_mage = Character.add_status_effect(mage, %{type: :hex, value: 2})
      original_hp = hexed_mage.hp

      # apply_damage with negative = healing; hex flips it to damage
      updated = Character.apply_damage(hexed_mage, -5)
      assert updated.hp == original_hp - 5
    end

    test "non-hexed character takes damage normally", %{mage: mage} do
      original_hp = mage.hp
      updated = Character.apply_damage(mage, 5)
      assert updated.hp == original_hp - 5
    end
  end

  describe "hex with shield (shield absorbs first, then hex flips remainder)" do
    test "shield absorbs all damage — no hp change, hex irrelevant", %{mage: mage} do
      hexed_shielded =
        mage
        |> Character.add_status_effect(%{type: :hex, value: 2})
        |> Character.add_status_effect(%{type: :shield, value: 10})

      original_hp = hexed_shielded.hp

      updated = Character.apply_damage(hexed_shielded, 3)
      assert updated.hp == original_hp
      assert Character.get_status_effect(updated, :shield).value == 7
    end

    test "shield absorbs partial damage — hex flips remainder to healing", %{mage: mage} do
      # shield=3, damage=5: shield absorbs 3, remainder=2, hex flips 2 → healing
      hexed_shielded =
        mage
        |> Character.add_status_effect(%{type: :hex, value: 2})
        |> Character.add_status_effect(%{type: :shield, value: 3})

      original_hp = hexed_shielded.hp

      updated = Character.apply_damage(hexed_shielded, 5)
      assert updated.hp == original_hp + 2
      assert Character.get_status_effect(updated, :shield) == nil
    end
  end

  describe "hex countdown via setup_player_turn" do
    test "hex ticks down by 1 each turn", %{combat: combat, mage: mage} do
      hexed_mage = Character.add_status_effect(mage, %{type: :hex, value: 2})
      combat = %{combat | queue: [hexed_mage]}

      next =
        combat
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()

      hex = Character.get_status_effect(next.current_turn.player, :hex)
      assert hex.value == 1
    end

    test "hex is removed when it reaches 0", %{combat: combat, mage: mage} do
      hexed_mage = Character.add_status_effect(mage, %{type: :hex, value: 1})
      combat = %{combat | queue: [hexed_mage]}

      next =
        combat
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()

      assert Character.get_status_effect(next.current_turn.player, :hex) == nil
    end
  end

  describe "protocol contracts" do
    test "get_description/1" do
      assert is_binary(CardEffect.get_description(%Hex{value: 2}))
    end

    test "get_icon/1" do
      assert is_binary(CardEffect.get_icon(%Hex{}))
    end

    test "get_value_label/1" do
      assert is_binary(CardEffect.get_value_label(%Hex{value: 2}))
    end

    test "animate/1" do
      assert %{label: _, color: _} = CardEffect.animate(%Hex{})
    end
  end
end
