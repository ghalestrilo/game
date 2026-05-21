defmodule Game.Combat.CardEffects.DotTest do
  use ExUnit.Case, async: true

  alias Game.Combat.CardEffect
  alias Game.Combat.CardEffects.Dot
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
    test "adds dot status effect with damage and duration", %{combat: combat, mage: mage} do
      updated = CardEffect.process(%Dot{value: 3, damage: 5}, mage, combat)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      dot = Character.get_status_effect(updated_mage, :dot)
      assert dot != nil
      assert dot.damage == 5
      assert dot.value == 3
    end
  end

  describe "dot damage via setup_player_turn" do
    test "dot applies damage at the start of the affected player's turn", %{
      combat: combat,
      mage: mage
    } do
      dotted_mage = Character.add_status_effect(mage, %{type: :dot, damage: 4, value: 2})
      original_hp = dotted_mage.hp
      combat = %{combat | queue: [dotted_mage]}

      next =
        combat
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()

      assert next.current_turn.player.hp == original_hp - 4
    end

    test "dot fires on the last tick (value: 1) then is removed", %{
      combat: combat,
      mage: mage
    } do
      dotted_mage = Character.add_status_effect(mage, %{type: :dot, damage: 3, value: 1})
      original_hp = dotted_mage.hp
      combat = %{combat | queue: [dotted_mage]}

      next =
        combat
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()

      assert next.current_turn.player.hp == original_hp - 3
      assert Character.get_status_effect(next.current_turn.player, :dot) == nil
    end

    test "dot fires n times over n turns", %{combat: combat, mage: mage} do
      dotted_mage = Character.add_status_effect(mage, %{type: :dot, damage: 2, value: 2})
      original_hp = dotted_mage.hp
      combat = %{combat | queue: [dotted_mage]}

      # Mage turn 1: damage fires, value 2→1
      after_turn1 =
        combat
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()

      assert after_turn1.current_turn.player.hp == original_hp - 2

      # Fighter turn
      after_fighter =
        after_turn1
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()

      # Mage turn 2: damage fires again, value 1→0, removed
      after_turn2 =
        after_fighter
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()

      assert after_turn2.current_turn.player.id == mage.id
      assert after_turn2.current_turn.player.hp == original_hp - 4
      assert Character.get_status_effect(after_turn2.current_turn.player, :dot) == nil
    end

    test "dot damage is absorbed by shield", %{combat: combat, mage: mage} do
      dotted_shielded_mage =
        mage
        |> Character.add_status_effect(%{type: :dot, damage: 3, value: 1})
        |> Character.add_status_effect(%{type: :shield, value: 10})

      original_hp = dotted_shielded_mage.hp
      combat = %{combat | queue: [dotted_shielded_mage]}

      next =
        combat
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()

      # HP should be unchanged — shield absorbed the dot damage
      assert next.current_turn.player.hp == original_hp
      shield = Character.get_status_effect(next.current_turn.player, :shield)
      assert shield.value == 7
    end
  end

  describe "dot kill — character dies from DOT damage" do
    test "character with enough DOT damage is marked dead at start of their turn", %{
      combat: combat,
      mage: mage
    } do
      # Mage has 15 HP; DOT of 20 damage over 1 tick kills them
      lethal_mage = Character.add_status_effect(mage, %{type: :dot, damage: 20, value: 1})
      combat = %{combat | queue: [lethal_mage]}

      next =
        combat
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()

      dead_mage = Enum.find(CombatState.get_current_queue(next), &(&1.id == mage.id))
      assert dead_mage.hp <= 0
      assert dead_mage.dead == true
    end

    test "dead-from-DOT character's turn is skipped — next alive player acts", %{
      combat: combat,
      fighter: fighter,
      mage: mage
    } do
      # Mage has 15 HP; DOT of 20 kills them on their turn
      lethal_mage = Character.add_status_effect(mage, %{type: :dot, damage: 20, value: 1})
      combat = %{combat | queue: [lethal_mage]}

      # Rotate to mage: DOT fires, mage dies, turn skips back to fighter
      next =
        combat
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()

      assert next.current_turn.player.id == fighter.id,
             "fighter should be current player after dead mage's turn is skipped"
    end

    test "dead-from-DOT character appears in dead_characters getter", %{
      combat: combat,
      mage: mage
    } do
      lethal_mage = Character.add_status_effect(mage, %{type: :dot, damage: 20, value: 1})
      combat = %{combat | queue: [lethal_mage]}

      next =
        combat
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()

      assert Enum.any?(CombatState.dead_characters(next), &(&1.id == mage.id))
    end
  end

  describe "protocol contracts" do
    test "get_description/1" do
      assert is_binary(CardEffect.get_description(%Dot{value: 2, damage: 5}))
    end

    test "get_icon/1 returns a string" do
      assert is_binary(CardEffect.get_icon(%Dot{}))
    end

    test "get_value_label/1 returns a string" do
      assert is_binary(CardEffect.get_value_label(%Dot{value: 2, damage: 5}))
    end

    test "animate/1 returns label and color" do
      assert %{label: _, color: _} = CardEffect.animate(%Dot{damage: 5})
    end
  end
end
