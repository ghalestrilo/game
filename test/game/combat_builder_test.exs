defmodule Game.CombatBuilderTest do
  use Game.DataCase, async: false

  alias Game.{CombatBuilder, CombatState, Maps.MapTemplate, MapObject}

  setup do
    Game.DataCase.seed_base_classes()
    :ok
  end

  defp all_positions(combat) do
    CombatState.get_current_queue(combat) |> Enum.map(& &1.position)
  end

  # Specs with no :position key — CombatBuilder must assign positions.
  defp positionless_specs do
    [
      %{class: "fighter", team: 1, id: 0},
      %{class: "mage", team: 2, id: 1}
    ]
  end

  defp map_with_two_spawn_points do
    %MapTemplate{
      name: "test_map",
      display_name: "Test",
      tiles: %{},
      spawn_points: %{team_1: {-3, 0, 3}, team_2: {3, 0, -3}}
    }
  end

  describe "build/2 with positionless specs and a map" do
    test "places characters at map spawn points" do
      combat = CombatBuilder.build(positionless_specs(), map: "two_towers")
      positions = all_positions(combat)

      # Both spawn points should be occupied
      assert {-3, 0, 3} in positions or {3, 0, -3} in positions
      assert length(positions) == 2
    end

    test "all characters land on distinct tiles" do
      combat = CombatBuilder.build(positionless_specs(), map: "two_towers")
      positions = all_positions(combat)
      assert length(positions) == length(Enum.uniq(positions))
    end

    test "extra characters beyond spawn point count get free tiles" do
      # two_towers has 2 spawn points; add a third character
      specs = positionless_specs() ++ [%{class: "fighter", team: 1, id: 2}]
      combat = CombatBuilder.build(specs, map: "two_towers")

      positions = all_positions(combat)
      assert length(positions) == 3
      assert length(Enum.uniq(positions)) == 3
    end

    test "extra characters are not placed on wall tiles" do
      specs = positionless_specs() ++ [%{class: "fighter", team: 1, id: 2}]
      combat = CombatBuilder.build(specs, map: "two_towers")

      wall_coords =
        combat.grid.tiles
        |> Enum.filter(fn {_, tile} ->
          Enum.any?(tile[:objects] || [], &match?(%MapObject.Wall{}, &1))
        end)
        |> Enum.map(fn {coord, _} -> coord end)
        |> MapSet.new()

      positions = all_positions(combat) |> MapSet.new()
      assert MapSet.disjoint?(positions, wall_coords)
    end
  end

  describe "build/2 with positionless specs and no map" do
    test "assigns distinct free tiles to all characters" do
      combat = CombatBuilder.build(positionless_specs())
      positions = all_positions(combat)
      assert length(positions) == 2
      assert length(Enum.uniq(positions)) == 2
    end
  end

  describe "build/2 with explicit positions (existing behavior)" do
    test "respects provided positions unchanged" do
      specs = [
        %{class: "fighter", team: 1, position: {0, 0, 0}, id: 0},
        %{class: "mage", team: 2, position: {2, -1, -1}, id: 1}
      ]

      combat = CombatBuilder.build(specs)
      positions = all_positions(combat)
      assert {0, 0, 0} in positions
      assert {2, -1, -1} in positions
    end
  end
end
