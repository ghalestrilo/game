defmodule Game.Combat.CardEffects.SummonTest do
  use ExUnit.Case, async: true

  alias Game.Combat.CardEffect
  alias Game.Combat.CardEffects.Summon
  alias Game.{CombatState, Grid, Fixtures}

  describe "Summon effect" do
    setup do
      warrior = Fixtures.warrior()
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

      summon_character = %{Fixtures.warrior() | id: 3, name: "Summoned Warrior"}
      summon_effect = %Summon{type: :summon, character: summon_character}

      {:ok, combat_state: combat_state, summon_effect: summon_effect}
    end

    test "process/3 currently returns unchanged combat state (WIP)", %{
      combat_state: combat_state,
      summon_effect: summon_effect
    } do
      target = Fixtures.warrior()
      updated_state = CardEffect.process(summon_effect, target, combat_state)

      # Currently WIP, should return unchanged state
      assert updated_state == combat_state
    end

    test "get_description/1 returns WIP summon description", %{summon_effect: summon_effect} do
      description = CardEffect.get_description(summon_effect)
      assert description == "[WIP] Summons a Summoned Warrior at seleted tile"
    end
  end
end
