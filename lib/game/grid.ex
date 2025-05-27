defmodule Game.Grid do
  alias __MODULE__

  @doc """
  Map of {q, r, s} => tile info
  """
  defstruct tiles: %{}

  @doc """
  Creates a new contiguous hex grid with the specified radius.
  The grid will be centered at (0,0,0) and extend outward by the given radius.
  Each tile will be initialized with basic terrain and no occupants.

  ## Parameters
    * `radius` - A tuple {x, y, z} specifying the radius in each direction.
                 For example, {1,1,1} creates a single cell at (0,0,0),
                 {2,2,2} creates a grid with 7 cells (center + 6 neighbors).

  ## Examples
      iex> Game.Grid.new({1,1,1}) |> Map.get(:tiles) |> Map.keys()
      [{{0, 0, 0}}]

      iex> Game.Grid.new({2,2,2}) |> Map.get(:tiles) |> Map.keys()
      [
        {0, 0, 0},
        {1, 0, -1}, {0, 1, -1}, {-1, 1, 0},
        {-1, 0, 1}, {0, -1, 1}, {1, -1, 0}
      ]
  """
  def new(radius) do
    {x, y, z} = radius
    tiles = for q <- -x..x,
                r <- -y..y,
                s <- -z..z,
                q + r + s == 0,
                abs(q) <= x and abs(r) <= y and abs(s) <= z do
      {{q, r, s}, %{terrain: :floor, occupied_by: nil}}
    end
    |> Map.new()

    %Grid{tiles: tiles}
  end

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
