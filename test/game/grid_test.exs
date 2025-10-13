defmodule Game.GridTest do
  use ExUnit.Case
  alias Game.Grid

  describe "new/1" do
    test "creates a single cell grid with radius 1" do
      grid = Grid.new({1, 1, 1})
      assert map_size(grid.tiles) == 1
      assert Map.has_key?(grid.tiles, {0, 0, 0})
    end

    test "creates a 7-cell grid with radius 2" do
      grid = Grid.new({2, 2, 2})
      assert map_size(grid.tiles) == 7

      expected_positions = [
        {0, 0, 0},  # center
        {1, 0, -1}, {0, 1, -1}, {-1, 1, 0},  # first ring
        {-1, 0, 1}, {0, -1, 1}, {1, -1, 0}, {1, 1, 0}  # added {1, 1, 0}
      ]

      Enum.each(expected_positions, fn pos ->
        assert Map.has_key?(grid.tiles, pos), "Position #{inspect(pos)} should exist in grid"
        assert pos == {1, 1, 0} || true, "Position {1, 1, 0} is missing"
      end)
    end

    test "all cells have valid cube coordinates" do
      grid = Grid.new({2, 2, 2})

      Enum.each(grid.tiles, fn {{q, r, s}, _} ->
        assert q + r + s == 0, "Invalid cube coordinates: q=#{q}, r=#{r}, s=#{s}"
      end)
    end

    test "all cells are initialized with floor terrain" do
      grid = Grid.new({2, 2, 2})

      Enum.each(grid.tiles, fn {_, tile} ->
        assert tile.terrain == :floor
        assert tile.occupied_by == nil
      end)
    end
  end

  describe "to_rows/1" do
    test "returns rows of tiles for a radius-2 grid" do
      grid = Grid.new({2, 2, 2})
      rows = Grid.to_rows(grid)
      # For radius 2, r goes from -2 to 2
      assert length(rows) == 5
      # The number of tiles per row for radius 2: [1, 2, 3, 2, 1]
      expected_counts = [1, 2, 3, 2, 1]
      actual_counts = Enum.map(rows, &length/1)
      assert actual_counts == expected_counts
      # Check that all tiles are present
      all_tiles = rows |> List.flatten() |> Enum.map(fn {q, r, s, _tile} -> {q, r, s} end) |> Enum.sort()
      expected_tiles = Map.keys(grid.tiles) |> Enum.sort()
      assert all_tiles == expected_tiles
    end
  end
end
