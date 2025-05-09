defmodule Game.Grid do
  alias __MODULE__

  @doc """
  Map of {q, r, s} => tile info
  """
  defstruct tiles: %{}

  @doc """
  Returns the distance in tiles between two positions on a hex grid
  Using cube coordinates (q, r, s) where q + r + s = 0
  """
  def distance(%Grid{}, {q1, r1, s1}, {q2, r2, s2}) do
    # In cube coordinates, distance is max absolute difference of coordinates
    [abs(q1 - q2), abs(r1 - r2), abs(s1 - s2)]
    |> Enum.max()
  end

  @doc """
  Returns true if a tile is blocked (wall or occupied)
  """
  def tile_blocked?(%Grid{tiles: tiles}, target_position) do
    case Map.get(tiles, target_position) do
      nil -> true
      %{terrain: :wall} -> true
      %{occupied_by: character} when not is_nil(character) -> true
      _ -> false
    end
  end

  @doc """
  Returns the character at the given position, if any
  """
  def get_object(%Grid{tiles: tiles}, position) do
    case Map.get(tiles, position) do
      %{occupied_by: character} when not is_nil(character) -> character
      _ -> nil
    end
  end

  @doc """
  Updates a character's position on the grid
  """
  def update_position(%Grid{} = grid, character, old_position, new_position) do
    # First clear the old position
    grid = %{grid | tiles: Map.update!(grid.tiles, old_position, &%{&1 | occupied_by: nil})}
    # Then set the new position
    %{grid | tiles: Map.update!(grid.tiles, new_position, &%{&1 | occupied_by: character})}
  end

  @doc """
  Updates a character's state at their current position
  """
  def update_character(%Grid{tiles: tiles} = grid, character) do
    %{grid | tiles: Map.update!(tiles, character.position, &%{&1 | occupied_by: character})}
  end

  @doc """
  Removes a character from the grid
  """
  def remove_character(%Grid{tiles: tiles} = grid, character) do
    %{grid | tiles: Map.update!(tiles, character.position, &%{&1 | occupied_by: nil})}
  end
end
