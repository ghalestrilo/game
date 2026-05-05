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

  describe "distance_from_caster context variable" do
    test "resolves to the correct scalar hex distance", %{combat: combat, mage: mage} do
      # fighter at {0,0,0}, mage at {2,0,-2} — cube distance = 2
      card = %Game.Card{
        id: 50,
        name: "Distance Test",
        cost: 0,
        range: 5,
        effects: [
          %Game.BaseCards.BaseCard.Effect{
            type: "damage",
            value: %{"var" => "distance_from_caster"}
          }
        ],
        targeting: %{"type" => "character"}
      }

      {updated, _anims} = Game.Card.process_card(combat, mage, card)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert mage.hp - updated_mage.hp == 2
    end

    test "distance is 1 when target is adjacent to caster", %{combat: combat, fighter: fighter} do
      adjacent_mage = %{Fixtures.mage() | position: {1, 0, -1}}

      combat = %{
        combat
        | grid: %{
            combat.grid
            | tiles: Map.put(combat.grid.tiles, {1, 0, -1}, %{
                terrain: :plain,
                occupied_by: adjacent_mage
              })
          },
          queue: [adjacent_mage],
          __constants__: %{players: [fighter, adjacent_mage]}
      }

      card = %Game.Card{
        id: 51,
        name: "Distance Test",
        cost: 0,
        range: 5,
        effects: [
          %Game.BaseCards.BaseCard.Effect{
            type: "damage",
            value: %{"var" => "distance_from_caster"}
          }
        ],
        targeting: %{"type" => "character"}
      }

      {updated, _anims} = Game.Card.process_card(combat, adjacent_mage, card)
      updated_mage = Enum.find(updated.queue, &(&1.id == adjacent_mage.id))
      assert adjacent_mage.hp - updated_mage.hp == 1
    end
  end

  describe "Pull Towards Me card (value: %{\"var\" => \"pull_delta\"})" do
    # This card uses a formula that resolves to the hex direction from target toward caster.
    # It exercises the full pipeline: formula context injection → JsonLogic resolution →
    # Move.process applying the resulting delta.

    defp pull_card do
      %Game.Card{
        id: 99,
        name: "Pull Towards Me",
        cost: 1,
        range: 3,
        effects: [
          %Game.BaseCards.BaseCard.Effect{
            type: "move",
            value: %{"var" => "pull_delta"}
          }
        ],
        targeting: %{"type" => "character"}
      }
    end

    test "pulls target one tile toward the caster", %{combat: combat, mage: mage} do
      # caster (fighter) at {0,0,0}, target (mage) at {2,0,-2}
      # direction from mage toward fighter: {-1,0,1}
      # expected new position: {2,0,-2} + {-1,0,1} = {1,0,-1}
      {updated, _anims} = Game.Card.process_card(combat, mage, pull_card())
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert updated_mage.position == {1, 0, -1}
    end

    test "is a no-op when the tile between target and caster is blocked", %{
      combat: combat,
      mage: mage,
      fighter: fighter
    } do
      # Place another character at {1,0,-1} (directly between mage and fighter)
      blocker = %{Fixtures.fighter() | id: 999, position: {1, 0, -1}}

      blocked_combat = %{
        combat
        | grid: %{
            combat.grid
            | tiles: Map.put(combat.grid.tiles, {1, 0, -1}, %{
                terrain: :plain,
                occupied_by: blocker
              })
          },
          __constants__: %{players: [fighter, mage, blocker]},
          queue: [mage, blocker]
      }

      {updated, _anims} = Game.Card.process_card(blocked_combat, mage, pull_card())
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert updated_mage.position == mage.position
    end

    test "pulls target toward caster from a different axis", %{fighter: fighter} do
      # Rearrange: mage at {0,2,-2}, fighter at {0,0,0}
      # direction from mage toward fighter: {0,-1,1}
      # expected new position: {0,2,-2} + {0,-1,1} = {0,1,-1}
      mage = %{Fixtures.mage() | position: {0, 2, -2}}

      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: fighter},
          {0, 1, -1} => %{terrain: :plain, occupied_by: nil},
          {0, 2, -2} => %{terrain: :plain, occupied_by: mage}
        }
      }

      combat = %CombatState{
        state: :running,
        __constants__: %{players: [fighter, mage]},
        queue: [mage],
        grid: grid,
        current_turn: %{starting_position: fighter.position, player: fighter, card: nil}
      }

      {updated, _anims} = Game.Card.process_card(combat, mage, pull_card())
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert updated_mage.position == {0, 1, -1}
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
