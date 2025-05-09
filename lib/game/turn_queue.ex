defmodule Game.TurnQueue do
  @doc """
  Removes a character from the queue
  """
  def remove_character(queue, character_id) do
    Enum.reject(queue, &(&1.id == character_id))
  end

  @doc """
  Updates a character's state in the queue
  """
  def update_character(queue, character) do
    Enum.map(queue, fn p ->
      if p.id == character.id, do: character, else: p
    end)
  end

  @doc """
  Moves the current player to the end of the queue
  """
  def rotate([current | rest], updated_player) do
    rest ++ [updated_player]
  end

  @doc """
  Returns true if it's the given player's turn
  """
  def is_players_turn?([current | _], player), do: current.id == player.id
end
