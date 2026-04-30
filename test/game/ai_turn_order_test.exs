defmodule Game.AITurnOrderTest do
  @moduledoc """
  Verifies turn-order behaviour in three-player combats with and without AI-controlled
  characters, mirroring the logic in CampaignPlayLive.maybe_run_ai_turn/1.
  """
  use ExUnit.Case, async: true

  alias Game.{AI, Combat, Character, CombatState, Grid, Fixtures}

  # Mirrors CampaignPlayLive.maybe_run_ai_turn/1 exactly.
  defp run_ai_turns(%{combat: %{current_turn: %{player: player}} = combat} = game_state) do
    if Character.is_ai_controlled?(player) do
      {:ok, updated_combat} = AI.run_turn(combat, player.tactics)
      run_ai_turns(%{game_state | combat: updated_combat})
    else
      game_state
    end
  end

  defp skip(%{combat: combat} = game_state) do
    player = CombatState.get_current_player(combat)
    {:ok, updated_combat} = Combat.process_action(combat, {:skip_turn, player})
    run_ai_turns(%{game_state | combat: updated_combat})
  end

  defp current_player(%{combat: combat}), do: CombatState.get_current_player(combat)

  # Builds a 3-character CombatState without touching the DB.
  defp build_combat(p1, p2, p3) do
    chars = [
      p1 |> Map.put(:id, 1) |> Map.put(:position, {0, 0, 0}) |> Map.put(:team, :team1),
      p2 |> Map.put(:id, 2) |> Map.put(:position, {1, 0, -1}) |> Map.put(:team, :team2),
      p3 |> Map.put(:id, 3) |> Map.put(:position, {2, 0, -2}) |> Map.put(:team, :team2)
    ]

    grid = %Grid{
      tiles: %{
        {0, 0, 0}   => %{terrain: :plain, occupied_by: Enum.at(chars, 0)},
        {1, 0, -1}  => %{terrain: :plain, occupied_by: Enum.at(chars, 1)},
        {2, 0, -2}  => %{terrain: :plain, occupied_by: Enum.at(chars, 2)}
      }
    }

    combat =
      %CombatState{
        state: :running,
        __constants__: %{players: chars},
        queue: chars,
        grid: grid
      }
      |> CombatState.initialize_queue()
      |> CombatState.setup_player_turn()

    %{combat: combat}
  end

  defp manual_player(base) do
    %{base | tactics: []}
  end

  defp skip_ai_player(base) do
    %{base | tactics: [%{"trigger" => true, "action" => "skip_turn"}]}
  end

  describe "all-manual three-player combat" do
    setup do
      p1 = manual_player(Fixtures.fighter())
      p2 = manual_player(Fixtures.mage())
      p3 = manual_player(%{Fixtures.fighter2() | id: 3, position: {2, 0, -2}})
      {:ok, game_state: build_combat(p1, p2, p3)}
    end

    test "starts on player 1", %{game_state: gs} do
      assert current_player(gs).id == 1
    end

    test "skipping once gives turn to player 2", %{game_state: gs} do
      gs = skip(gs)
      assert current_player(gs).id == 2
    end

    test "skipping twice gives turn to player 3", %{game_state: gs} do
      gs = gs |> skip() |> skip()
      assert current_player(gs).id == 3
    end

    test "skipping three times returns to player 1", %{game_state: gs} do
      gs = gs |> skip() |> skip() |> skip()
      assert current_player(gs).id == 1
    end
  end

  describe "three-player combat where player 2 has a skip-turn AI strategy" do
    setup do
      p1 = manual_player(Fixtures.fighter())
      p2 = skip_ai_player(Fixtures.mage())
      p3 = manual_player(%{Fixtures.fighter2() | id: 3, position: {2, 0, -2}})
      {:ok, game_state: build_combat(p1, p2, p3)}
    end

    test "starts on player 1", %{game_state: gs} do
      assert current_player(gs).id == 1
    end

    test "player 1 skipping jumps over AI player 2 directly to player 3", %{game_state: gs} do
      gs = skip(gs)
      assert current_player(gs).id == 3
    end

    test "after player 3 skips, it returns to player 1", %{game_state: gs} do
      # p1 skips → AI p2 auto-skips → p3's turn → p3 skips → AI p2 auto-skips → p1's turn
      gs = gs |> skip() |> skip()
      assert current_player(gs).id == 1
    end

    test "player 2 never appears as the active player", %{game_state: gs} do
      players_seen =
        Enum.reduce(1..6, {gs, []}, fn _, {state, seen} ->
          new_state = skip(state)
          {new_state, [current_player(new_state).id | seen]}
        end)
        |> elem(1)

      refute 2 in players_seen
    end
  end
end
