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

  describe "build/2 grid faithfulness to map template" do
    test "grid contains exactly the tiles defined in the DB map — no extra tiles generated" do
      # 3-tile map: only these coords should exist in the combat grid.
      {:ok, map} =
        Game.Maps.create_map(%{
          slug: "faithfulness_test",
          display_name: "Faithfulness Test",
          tiles: [
            %{"q" => 0, "r" => 0, "s" => 0, "terrain" => "plain", "objects" => []},
            %{"q" => 1, "r" => 0, "s" => -1, "terrain" => "plain", "objects" => []},
            %{"q" => -1, "r" => 0, "s" => 1, "terrain" => "plain", "objects" => []}
          ],
          spawn_points: %{"team_1" => [0, 0, 0], "team_2" => [1, 0, -1]}
        })

      specs = [
        %{class: "fighter", team: 1, position: {0, 0, 0}, id: 0},
        %{class: "mage", team: 2, position: {1, 0, -1}, id: 1}
      ]

      combat = CombatBuilder.build(specs, map: "faithfulness_test")

      grid_coords = MapSet.new(Map.keys(combat.grid.tiles))
      expected_coords = MapSet.new([{0, 0, 0}, {1, 0, -1}, {-1, 0, 1}])

      assert grid_coords == expected_coords,
             "Expected grid to contain exactly the map tiles, got extra: #{inspect(MapSet.difference(grid_coords, expected_coords) |> MapSet.to_list())}"
    end

    test "characters cannot move to coordinates outside the DB map" do
      # 4-tile corridor: {0,0,0}..{3,0,-3}. Any move east off the end must be rejected.
      {:ok, _map} =
        Game.Maps.create_map(%{
          slug: "corridor_test",
          display_name: "Corridor Test",
          tiles: [
            %{"q" => 0, "r" => 0, "s" => 0, "terrain" => "plain", "objects" => []},
            %{"q" => 1, "r" => 0, "s" => -1, "terrain" => "plain", "objects" => []},
            %{"q" => 2, "r" => 0, "s" => -2, "terrain" => "plain", "objects" => []},
            %{"q" => 3, "r" => 0, "s" => -3, "terrain" => "plain", "objects" => []}
          ],
          spawn_points: %{"team_1" => [0, 0, 0], "team_2" => [3, 0, -3]}
        })

      specs = [
        %{class: "fighter", team: 1, position: {0, 0, 0}, id: 0},
        %{class: "mage", team: 2, position: {3, 0, -3}, id: 1}
      ]

      combat = CombatBuilder.build(specs, map: "corridor_test")

      # {4,0,-4} is off the map — movement there must be rejected
      result = Game.Combat.process_action(combat, {:move, combat.current_turn.player, {4, 0, -4}})
      assert {:error, _} = result

      # {3,0,-3} is occupied by mage — also blocked
      result2 = Game.Combat.process_action(combat, {:move, combat.current_turn.player, {3, 0, -3}})
      assert {:error, _} = result2

      # {1,0,-1} is on the map and free — movement allowed
      {:ok, updated} =
        Game.Combat.process_action(combat, {:move, combat.current_turn.player, {1, 0, -1}})

      player_pos = updated.current_turn.player.position
      map_coords = MapSet.new([{0, 0, 0}, {1, 0, -1}, {2, 0, -2}, {3, 0, -3}])

      assert MapSet.member?(map_coords, player_pos),
             "Player ended up at #{inspect(player_pos)}, which is outside the map"
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
