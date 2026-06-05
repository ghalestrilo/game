defmodule Game.GridTest do
  use ExUnit.Case
  alias Game.Grid

  describe "new/1" do
    test "creates a 7-single cell grid with radius 1" do
      grid = Grid.new({1, 1, 1})
      assert map_size(grid.tiles) == 7
      assert Map.has_key?(grid.tiles, {0, 0, 0})
    end

    test "creates a 19-cell grid with radius 2" do
      grid = Grid.new({2, 2, 2})
      assert map_size(grid.tiles) == 19

      # Verify center and some key positions exist
      expected_positions = [
        # center
        {0, 0, 0},
        # first ring (6 neighbors)
        {1, 0, -1},
        {0, 1, -1},
        {-1, 1, 0},
        {-1, 0, 1},
        {0, -1, 1},
        {1, -1, 0},
        # second ring (some samples)
        {2, 0, -2},
        {0, 2, -2},
        {-2, 2, 0}
      ]

      Enum.each(expected_positions, fn pos ->
        assert Map.has_key?(grid.tiles, pos), "Position #{inspect(pos)} should exist in grid"
      end)
    end

    test "all cells have valid cube coordinates" do
      grid = Grid.new({2, 2, 2})

      Enum.each(grid.tiles, fn {{q, r, s}, _} ->
        assert q + r + s == 0, "Invalid cube coordinates: q=#{q}, r=#{r}, s=#{s}"
      end)
    end

    test "all cells are initialized with plain terrain" do
      grid = Grid.new({2, 2, 2})

      Enum.each(grid.tiles, fn {_, tile} ->
        assert tile.terrain == :plain
        assert tile.occupied_by == nil
      end)
    end
  end

  describe "has_linear_path?/3" do
    test "returns true for adjacent tiles with no obstacles" do
      grid = Grid.new({2, 2, 2})
      assert Grid.has_linear_path?(grid, {0, 0, 0}, {1, 0, -1})
    end

    test "returns true for clear line of distance 2" do
      grid = Grid.new({3, 3, 3})
      assert Grid.has_linear_path?(grid, {0, 0, 0}, {2, 0, -2})
    end

    test "returns false when intermediate tile is a wall" do
      grid = Grid.new({3, 3, 3})
      grid = put_in(grid.tiles[{1, 0, -1}].terrain, :wall)
      refute Grid.has_linear_path?(grid, {0, 0, 0}, {2, 0, -2})
    end

    test "returns true when only the target tile is occupied by a character" do
      grid = Grid.new({3, 3, 3})
      char = %Game.Character{id: 1, position: {2, 0, -2}, name: "Enemy", team: :enemy}
      grid = Grid.update_character(grid, char)
      assert Grid.has_linear_path?(grid, {0, 0, 0}, {2, 0, -2})
    end

    test "returns false when intermediate tile is occupied by a character" do
      grid = Grid.new({3, 3, 3})
      char = %Game.Character{id: 1, position: {1, 0, -1}, name: "Blocker", team: :enemy}
      grid = Grid.update_character(grid, char)
      refute Grid.has_linear_path?(grid, {0, 0, 0}, {2, 0, -2})
    end

    test "returns true for same position (distance 0)" do
      grid = Grid.new({2, 2, 2})
      assert Grid.has_linear_path?(grid, {0, 0, 0}, {0, 0, 0})
    end

    test "returns true for clear diagonal line" do
      grid = Grid.new({3, 3, 3})
      assert Grid.has_linear_path?(grid, {0, 0, 0}, {0, 2, -2})
    end

    test "returns false when intermediate tile on diagonal is blocked" do
      grid = Grid.new({3, 3, 3})
      grid = put_in(grid.tiles[{0, 1, -1}].terrain, :wall)
      refute Grid.has_linear_path?(grid, {0, 0, 0}, {0, 2, -2})
    end
  end

  describe "astar_path_length/3" do
    test "returns {:ok, 0} for same position" do
      grid = Grid.new({2, 2, 2})
      assert {:ok, 0} = Grid.astar_path_length(grid, {0, 0, 0}, {0, 0, 0})
    end

    test "returns {:ok, 1} for adjacent plain tiles" do
      grid = Grid.new({2, 2, 2})
      assert {:ok, 1} = Grid.astar_path_length(grid, {0, 0, 0}, {1, 0, -1})
    end

    test "returns {:ok, 2} for two-step straight path" do
      grid = Grid.new({3, 3, 3})
      assert {:ok, 2} = Grid.astar_path_length(grid, {0, 0, 0}, {2, 0, -2})
    end

    test "returns :unreachable when wall blocks all paths on a small isolated grid" do
      # Build a minimal grid with only two tiles sharing one neighbor,
      # with that neighbor being a wall
      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: nil},
          {1, 0, -1} => %{terrain: :wall, occupied_by: nil},
          {2, 0, -2} => %{terrain: :plain, occupied_by: nil}
        }
      }

      assert :unreachable = Grid.astar_path_length(grid, {0, 0, 0}, {2, 0, -2})
    end

    test "finds path around an obstacle" do
      # Build a grid where the direct path is blocked but a detour exists
      # {0,0,0} -> {1,0,-1} blocked, but {0,1,-1} -> {1,0,-1} not needed — go around via {0,1,-1} -> {1,1,-2}...
      # simpler: just use a 3x3 grid, block {1,0,-1}, and target {2,0,-2}
      grid = Grid.new({3, 3, 3})
      grid = put_in(grid.tiles[{1, 0, -1}].terrain, :wall)
      assert {:ok, n} = Grid.astar_path_length(grid, {0, 0, 0}, {2, 0, -2})
      assert n > 2
    end

    test "can reach target tile occupied by a character" do
      grid = Grid.new({2, 2, 2})
      char = %Game.Character{id: 1, position: {1, 0, -1}, name: "Target", team: :enemy}
      grid = Grid.update_character(grid, char)
      assert {:ok, 1} = Grid.astar_path_length(grid, {0, 0, 0}, {1, 0, -1})
    end

    test "intermediate character blocks direct path, detour used when available" do
      grid = Grid.new({3, 3, 3})
      char = %Game.Character{id: 1, position: {1, 0, -1}, name: "Blocker", team: :enemy}
      grid = Grid.update_character(grid, char)
      assert {:ok, n} = Grid.astar_path_length(grid, {0, 0, 0}, {2, 0, -2})
      assert n > 2
    end

    test "returns :unreachable when blocking object seals only route" do
      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: nil},
          {1, 0, -1} => %{terrain: :plain, objects: [%Game.MapObject.Wall{}], occupied_by: nil},
          {2, 0, -2} => %{terrain: :plain, occupied_by: nil}
        }
      }

      assert :unreachable = Grid.astar_path_length(grid, {0, 0, 0}, {2, 0, -2})
    end
  end

  describe "to_rows/1" do
    test "returns rows of tiles for a radius-2 grid" do
      grid = Grid.new({2, 2, 2})
      rows = Grid.to_rows(grid)
      # For radius 2, r goes from -2 to 2
      assert length(rows) == 5
      # The number of tiles per row for radius 2: [3, 4, 5, 4, 3]
      expected_counts = [3, 4, 5, 4, 3]
      actual_counts = Enum.map(rows, &length/1)
      assert actual_counts == expected_counts
      # Check that all tiles are present
      all_tiles =
        rows |> List.flatten() |> Enum.map(fn {q, r, s, _tile} -> {q, r, s} end) |> Enum.sort()

      expected_tiles = Map.keys(grid.tiles) |> Enum.sort()
      assert all_tiles == expected_tiles
    end
  end
end
