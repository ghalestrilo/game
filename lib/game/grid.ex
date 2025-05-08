defmodule Game.Grid do
  alias __MODULE__

  @doc """
  Map of {q, r, s} => tile info
  """
  defstruct tiles: %{}

  @doc """
  Returns the distance in tiles between two positions
  Based on an A* algorithm implementation
  """
  def distance(%Grid{tiles: tiles}, starting_position, target_position) do
    # starting_position
    # |> AStar.find_path(target_position)
    # |> length()
    2
  end

  @doc """

  """
  def tile_blocked?(%Grid{tiles: tiles}, target_position) do
    case Map.get(tiles, target_position, nil) do
      nil -> false
      _tile -> true
    end
  end
end
