defmodule GameWeb.CombatActionHelpers do
  alias Game.{Combat, AI}

  def parse_hex_position(str) do
    case str |> String.split("_") |> Enum.map(&String.to_integer/1) do
      [q, r, s] -> {:ok, {q, r, s}}
      _ -> {:error, "Invalid position"}
    end
  rescue
    ArgumentError -> {:error, "Invalid position"}
  end

  def apply_combat_action(combat, action) do
    Combat.process_action(combat, action)
  end

  def force_game_over(combat, winning_team) do
    updated_queue =
      Enum.map(combat.queue, fn char ->
        if char.team != winning_team, do: %{char | dead: true, hp: 0}, else: char
      end)

    updated_player =
      if combat.current_turn.player && combat.current_turn.player.team != winning_team,
        do: %{combat.current_turn.player | dead: true, hp: 0},
        else: combat.current_turn.player

    %{
      combat
      | state: :game_over,
        queue: updated_queue,
        current_turn: %{combat.current_turn | player: updated_player}
    }
  end

  def maybe_run_ai_turn(%{combat: combat} = game_state) do
    {:ok, updated_combat} = AI.advance_through_ai_turns(combat)
    %{game_state | combat: updated_combat}
  end

  def checkpoint_combat(session_id, combat_state) do
    if combat_state.state == :game_over do
      Game.CombatSaves.delete(session_id)
    else
      Game.CombatSaves.save(session_id, combat_state)
    end
  end

  def my_turn?(socket) do
    me = socket.assigns.current_player
    current = socket.assigns.game_state.combat.current_turn.player
    me && current && me.id == current.id
  end
end
