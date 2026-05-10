defmodule Game.AITest do
  use ExUnit.Case, async: true

  alias Game.{AI, CombatState, Grid, Fixtures}

  defp build_combat(attacker_opts \\ [], target_opts \\ []) do
    attacker =
      Fixtures.fighter()
      |> Map.merge(Map.new(attacker_opts))
      |> Map.put(:tactics, [
        %{"trigger" => true, "action" => "damage", "card_filter" => "damage"},
        %{"trigger" => true, "action" => "skip_turn"}
      ])

    target =
      %{Fixtures.mage() | position: {1, 0, -1}}
      |> Map.merge(Map.new(target_opts))

    grid = %Grid{
      tiles: %{
        {0, 0, 0} => %{terrain: :plain, occupied_by: attacker},
        {1, 0, -1} => %{terrain: :plain, occupied_by: target}
      }
    }

    %CombatState{
      state: :running,
      __constants__: %{players: [attacker, target]},
      queue: [target],
      grid: grid,
      current_turn: %{player: attacker, starting_position: attacker.position, card: nil}
    }
  end

  describe "run_turn/2" do
    test "plays a damage card when enemy is in range" do
      attacker = %{
        Fixtures.fighter()
        | tactics: [
            %{"trigger" => true, "action" => "damage", "card_filter" => "damage"},
            %{"trigger" => true, "action" => "skip_turn"}
          ]
      }

      damage_card = %Game.Card{
        id: 1,
        name: "Strike",
        cost: 1,
        range: 5,
        effects: [%{"type" => "damage", "value" => 5}],
        targeting: %{"type" => "character", "rule" => %{"var" => "target.occupied"}}
      }

      attacker = put_in(attacker.cards.hand, [damage_card])
      target = %{Fixtures.mage() | position: {1, 0, -1}, hp: 15}

      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: attacker},
          {1, 0, -1} => %{terrain: :plain, occupied_by: target}
        }
      }

      combat = %CombatState{
        state: :running,
        __constants__: %{players: [attacker, target]},
        queue: [target],
        grid: grid,
        current_turn: %{player: attacker, starting_position: attacker.position, card: nil}
      }

      {:ok, result} = AI.run_turn(combat, attacker.tactics)

      all_chars = [result.current_turn.player | result.queue]
      updated_target = Enum.find(all_chars, &(&1.id == target.id))
      assert updated_target.hp < target.hp
    end

    test "falls through to skip_turn when no cards in hand" do
      attacker = %{
        Fixtures.fighter()
        | tactics: [
            %{"trigger" => true, "action" => "damage", "card_filter" => "damage"},
            %{"trigger" => true, "action" => "skip_turn"}
          ]
      }

      attacker = put_in(attacker.cards.hand, [])
      target = %{Fixtures.mage() | position: {1, 0, -1}}

      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: attacker},
          {1, 0, -1} => %{terrain: :plain, occupied_by: target}
        }
      }

      combat = %CombatState{
        state: :running,
        __constants__: %{players: [attacker, target]},
        queue: [target],
        grid: grid,
        current_turn: %{player: attacker, starting_position: attacker.position, card: nil}
      }

      {:ok, result} = AI.run_turn(combat, attacker.tactics)

      # Turn should have advanced (skip_turn rotates the queue)
      assert result.current_turn.player.id == target.id
    end

    @tag :skip
    test "conditional trigger: retreats when HP below 25%" do
      attacker = %{
        Fixtures.fighter()
        | hp: 4,
          max_hp: 20,
          tactics: [
            %{
              "trigger" => %{
                "<" => [%{"var" => "caster.hp"}, %{"*" => [%{"var" => "caster.max_hp"}, 0.25]}]
              },
              "action" => "move_away"
            },
            %{"trigger" => true, "action" => "skip_turn"}
          ]
      }

      target = %{Fixtures.mage() | position: {1, 0, -1}}

      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: attacker},
          {1, 0, -1} => %{terrain: :plain, occupied_by: target},
          {-1, 0, 1} => %{terrain: :plain, occupied_by: nil},
          {-1, 1, 0} => %{terrain: :plain, occupied_by: nil}
        }
      }

      combat = %CombatState{
        state: :running,
        __constants__: %{players: [attacker, target]},
        queue: [target],
        grid: grid,
        current_turn: %{player: attacker, starting_position: attacker.position, card: nil}
      }

      {:ok, result} = AI.run_turn(combat, attacker.tactics)

      updated_attacker = result.current_turn.player
      # Attacker should have moved away from the enemy at {1, 0, -1}
      old_dist = Game.Grid.distance(grid, attacker.position, target.position)
      new_dist = Game.Grid.distance(result.grid, updated_attacker.position, target.position)
      assert new_dist >= old_dist
    end

    test "circuit breaker stops infinite loops" do
      # A gambit that always succeeds but never advances the turn
      # (e.g. move_closer with nowhere to move) — should trip the breaker
      attacker = %{
        Fixtures.fighter()
        | tactics: [
            %{"trigger" => true, "action" => "move_closer"}
          ]
      }

      target = %{Fixtures.mage() | position: {1, 0, -1}}

      # No free tiles to move to
      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: attacker},
          {1, 0, -1} => %{terrain: :plain, occupied_by: target}
        }
      }

      combat = %CombatState{
        state: :running,
        __constants__: %{players: [attacker, target]},
        queue: [target],
        grid: grid,
        current_turn: %{player: attacker, starting_position: attacker.position, card: nil}
      }

      # Should not raise or loop forever
      assert {:ok, _result} = AI.run_turn(combat, attacker.tactics)
    end
  end
end
