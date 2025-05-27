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
        {-1, 0, 1}, {0, -1, 1}, {1, -1, 0}
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

    test "all cells are initialized with floor terrain" do
      grid = Grid.new({2, 2, 2})

      Enum.each(grid.tiles, fn {_, tile} ->
        assert tile.terrain == :floor
        assert tile.occupied_by == nil
      end)
    end
  end
end
