defmodule Game.Combat.CardEffects.MoveTest do
  use ExUnit.Case, async: true

  alias Game.Combat.CardEffect
  alias Game.Combat.CardEffects.Move
  alias Game.{CombatState, Grid, Fixtures}

  setup do
    fighter = Fixtures.fighter()
    mage = %{Fixtures.mage() | position: {2, 0, -2}}

    grid = %Grid{
      tiles: %{
        {0, 0, 0} => %{terrain: :plain, occupied_by: fighter},
        {1, 0, -1} => %{terrain: :plain, occupied_by: nil},
        {2, 0, -2} => %{terrain: :plain, occupied_by: mage},
        {3, 0, -3} => %{terrain: :plain, occupied_by: nil}
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

  describe "process/3 with tuple delta" do
    test "moves target to new position (current + delta)", %{combat: combat, mage: mage} do
      # mage at {2,0,-2}, push by {1,0,-1} → {3,0,-3}
      updated = CardEffect.process(%Move{value: {1, 0, -1}}, mage, combat)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert updated_mage.position == {3, 0, -3}
    end

    test "clears old tile and occupies new tile on the grid", %{combat: combat, mage: mage} do
      updated = CardEffect.process(%Move{value: {1, 0, -1}}, mage, combat)
      assert updated.grid.tiles[{2, 0, -2}].occupied_by == nil
      assert updated.grid.tiles[{3, 0, -3}].occupied_by.id == mage.id
    end

    test "can move the current player", %{combat: combat, fighter: fighter} do
      # fighter at {0,0,0}, push by {1,0,-1} → {1,0,-1}
      updated = CardEffect.process(%Move{value: {1, 0, -1}}, fighter, combat)
      assert updated.current_turn.player.position == {1, 0, -1}
    end
  end

  describe "process/3 with map delta" do
    test "moves target when delta is an atomized map", %{combat: combat, mage: mage} do
      updated = CardEffect.process(%Move{value: %{q: 1, r: 0, s: -1}}, mage, combat)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert updated_mage.position == {3, 0, -3}
    end
  end

  describe "process/3 no-op cases" do
    test "is a no-op when destination tile is out of bounds", %{combat: combat, mage: mage} do
      # push mage off the grid
      updated = CardEffect.process(%Move{value: {10, 0, -10}}, mage, combat)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert updated_mage.position == mage.position
    end

    test "is a no-op when destination tile is blocked", %{combat: combat, mage: mage} do
      # push mage toward fighter (at {0,0,0}) — {2,0,-2} + {-2,0,2} = {0,0,0}
      updated = CardEffect.process(%Move{value: {-2, 0, 2}}, mage, combat)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert updated_mage.position == mage.position
    end
  end

  describe "protocol contracts" do
    test "get_description/1" do
      assert is_binary(CardEffect.get_description(%Move{value: {1, 0, -1}}))
    end

    test "get_icon/1 returns a string" do
      assert is_binary(CardEffect.get_icon(%Move{}))
    end

    test "get_value_label/1 returns a string" do
      assert is_binary(CardEffect.get_value_label(%Move{value: {1, 0, -1}}))
    end

    test "animate/1 returns label and color" do
      assert %{label: _, color: _} = CardEffect.animate(%Move{})
    end
  end
end
