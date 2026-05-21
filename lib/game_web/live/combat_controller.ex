defmodule GameWeb.CombatController do
  import GameWeb.CombatActionHelpers, only: [my_turn?: 1, parse_hex_position: 1]

  @move_directions %{
    "d" => {1, 0, -1},
    "a" => {-1, 0, 1},
    "z" => {-1, 1, 0},
    "e" => {1, -1, 0},
    "q" => {0, -1, 1},
    "c" => {0, 1, -1}
  }

  @doc """
  Dispatches a combat intent from any source (keyboard, UI click).
  Validates turn ownership and calls Game.process_action/2.
  """
  def dispatch(socket, intent) do
    if not my_turn?(socket) do
      {:noreply, Phoenix.LiveView.put_flash(socket, :error, "It's not your turn")}
    else
      combat = socket.assigns.game_state.combat
      player = combat.current_turn.player
      game_pid = socket.assigns.game_pid

      case to_action(intent, player) do
        {:ok, action} ->
          Game.process_action(game_pid, action)
          {:noreply, log_action(socket, intent, player)}

        {:error, reason} ->
          {:noreply, Phoenix.LiveView.put_flash(socket, :error, reason)}
      end
    end
  end

  @doc """
  Translates a raw keydown string to a combat intent map, or nil if the key is unhandled.
  """
  def key_to_intent(key, combat)

  def key_to_intent(key, combat) when key in ~w(1 2 3 4 5 6 7 8 9) do
    hand = combat.current_turn.player.cards.hand
    idx = min(String.to_integer(key), length(hand)) - 1
    card = Enum.at(hand, idx)
    if card, do: %{type: :pick_card, card: card}, else: nil
  end

  def key_to_intent("Enter", _combat), do: %{type: :skip_turn}

  def key_to_intent(key, %{state: :running} = combat) when is_map_key(@move_directions, key) do
    {dq, dr, ds} = @move_directions[key]
    {q, r, s} = combat.current_turn.player.position
    %{type: :move, position: {q + dq, r + dr, s + ds}}
  end

  def key_to_intent(_key, _combat), do: nil

  @doc """
  Translates a LiveView "interact" event's params to a combat intent, given the current combat state.
  Returns nil if the event doesn't apply in the current state.
  """
  def event_to_intent("interact", %{"target_character_id" => id}, %{state: :card_selected} = combat) do
    character =
      Game.CombatState.get_current_queue(combat)
      |> Enum.find(&(to_string(&1.id) == id))

    if character, do: %{type: :play_card, character: character}, else: nil
  end

  def event_to_intent("interact", %{"target_position" => pos_str}, %{state: :card_selected}) do
    case parse_hex_position(pos_str) do
      {:ok, pos} -> %{type: :play_card, position: pos}
      _ -> nil
    end
  end

  def event_to_intent("interact", %{"target_position" => pos_str}, %{state: :running}) do
    case parse_hex_position(pos_str) do
      {:ok, pos} -> %{type: :move, position: pos}
      _ -> nil
    end
  end

  def event_to_intent(_event, _params, _combat), do: nil

  # --- private ---

  defp to_action(%{type: :move, position: pos}, player),
    do: {:ok, {:move, player, pos}}

  defp to_action(%{type: :pick_card, card: card}, player),
    do: {:ok, {:pick_card, player, card}}

  defp to_action(%{type: :play_card, position: pos}, _player),
    do: {:ok, {:play_card, pos}}

  defp to_action(%{type: :play_card, character: char}, _player),
    do: {:ok, {:play_card_on_character, char}}

  defp to_action(%{type: :skip_turn}, player),
    do: {:ok, {:skip_turn, player}}

  defp to_action(_, _), do: {:error, "Unknown intent"}

  defp log_action(socket, %{type: :skip_turn}, player),
    do: update_log(socket, "#{player.name} skipped their turn")

  defp log_action(socket, %{type: :pick_card, card: card}, player),
    do: update_log(socket, "#{player.name} selected card: #{card.name}")

  defp log_action(socket, %{type: :play_card}, player),
    do: update_log(socket, "#{player.name} played a card")

  defp log_action(socket, _, _player), do: socket

  defp update_log(socket, msg),
    do: Phoenix.Component.update(socket, :action_log, &Enum.slice([msg | &1], 0, 20))
end
