defmodule Game.Combat.CardEffects.StunTest do
  use ExUnit.Case, async: true

  alias Game.Combat.CardEffect
  alias Game.Combat.CardEffects.Stun
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
    test "adds stun status effect with value + 1 (like stealth, to account for tick)", %{
      combat: combat,
      mage: mage
    } do
      updated = CardEffect.process(%Stun{value: 2}, mage, combat)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      stun = Character.get_status_effect(updated_mage, :stun)
      assert stun != nil
      assert stun.value == 3
    end
  end

  describe "stun skips turns" do
    test "stunned player's turn is skipped — next player acts instead", %{
      combat: combat,
      fighter: fighter,
      mage: mage
    } do
      # Inject stun value: 2 directly (after +1 offset, this means 1 actual skip)
      stunned_mage = Character.add_status_effect(mage, %{type: :stun, value: 2})
      combat = %{combat | queue: [stunned_mage]}

      # Rotate to mage's turn — tick 2→1, still stunned → skip back to fighter
      next =
        combat
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()

      assert next.current_turn.player.id == fighter.id
    end

    test "stun ticks down each time the stunned player's turn is skipped", %{
      combat: combat,
      mage: mage
    } do
      # stun value: 3 (2 actual skips)
      stunned_mage = Character.add_status_effect(mage, %{type: :stun, value: 3})
      combat = %{combat | queue: [stunned_mage]}

      # Rotate to mage — tick 3→2, skip. fighter turn. Rotate to mage — tick 2→1, skip.
      # fighter turn. Rotate to mage — tick 1→0 (removed), mage takes turn.
      next =
        combat
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()

      assert next.current_turn.player.id == mage.id
      assert Character.get_status_effect(next.current_turn.player, :stun) == nil
    end

    test "player can act normally after stun expires", %{combat: combat, mage: mage} do
      # stun value: 2 (1 actual skip)
      stunned_mage = Character.add_status_effect(mage, %{type: :stun, value: 2})
      combat = %{combat | queue: [stunned_mage]}

      next =
        combat
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()

      assert next.current_turn.player.id == mage.id
    end

    test "all players stunned cycles until one expires", %{
      combat: combat,
      fighter: fighter,
      mage: mage
    } do
      # fighter stun=2 (1 skip), mage stun=3 (2 skips)
      # Rotate to mage: tick 3→2, skip → fighter. Tick fighter 2→1 still stunned, skip → mage.
      # Tick mage 2→1, skip → fighter. Tick fighter 1→0 removed → fighter acts.
      stunned_fighter = Character.add_status_effect(fighter, %{type: :stun, value: 2})
      stunned_mage = Character.add_status_effect(mage, %{type: :stun, value: 3})

      combat = %{
        combat
        | queue: [stunned_mage],
          current_turn: %{combat.current_turn | player: stunned_fighter}
      }

      next =
        combat
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()

      assert next.current_turn.player.id == fighter.id
    end
  end

  describe "protocol contracts" do
    test "get_description/1" do
      assert is_binary(CardEffect.get_description(%Stun{value: 2}))
    end

    test "get_icon/1 returns a string" do
      assert is_binary(CardEffect.get_icon(%Stun{}))
    end

    test "get_value_label/1 returns a string" do
      assert is_binary(CardEffect.get_value_label(%Stun{value: 2}))
    end

    test "animate/1 returns label and color" do
      assert %{label: _, color: _} = CardEffect.animate(%Stun{})
    end
  end
end
