defmodule GameWeb.Admin.MapEditorLiveTest do
  use GameWeb.ConnCase

  import Phoenix.LiveViewTest

  setup :register_and_log_in_admin

  defp plain_tile(q, r, s), do: %{"q" => q, "r" => r, "s" => s, "terrain" => "plain", "objects" => []}

  describe "map editor" do
    test "renders the game board for a map with no tiles", %{conn: conn} do
      {:ok, map} =
        Game.Maps.create_map(%{slug: "editor_test_empty", display_name: "Editor Test Empty",
          tiles: [], spawn_points: %{}})

      {:ok, _view, html} = live(conn, "/admin/maps/#{map.id}/edit-tiles")

      assert html =~ "game-board"
      assert html =~ "hex-cell"
    end

    test "renders the game board for a map with existing tiles", %{conn: conn} do
      {:ok, map} =
        Game.Maps.create_map(%{slug: "editor_test_tiles", display_name: "Editor Test Tiles",
          tiles: [plain_tile(0, 0, 0)], spawn_points: %{}})

      {:ok, _view, html} = live(conn, "/admin/maps/#{map.id}/edit-tiles")

      assert html =~ "game-board"
      assert html =~ "hex-cell"
    end

    test "terrain tool on OOB tile adds it to the map", %{conn: conn} do
      {:ok, map} =
        Game.Maps.create_map(%{slug: "editor_test_terrain_add", display_name: "Terrain Add",
          tiles: [], spawn_points: %{}})

      {:ok, view, _html} = live(conn, "/admin/maps/#{map.id}/edit-tiles")

      view |> element("button[phx-value-tool=\"terrain\"]") |> render_click()
      view |> element("[phx-value-target_position=\"0_0_0\"]") |> render_click()
      view |> element("button[phx-click=\"save\"]") |> render_click()

      updated = Game.Maps.get_map!(map.id)
      tile = Enum.find(updated.tiles, &(&1["q"] == 0 and &1["r"] == 0 and &1["s"] == 0))
      assert tile != nil
      assert tile["terrain"] == "plain"
      assert tile["objects"] == []
    end

    test "terrain tool on existing tile removes it from the map", %{conn: conn} do
      {:ok, map} =
        Game.Maps.create_map(%{slug: "editor_test_terrain_remove", display_name: "Terrain Remove",
          tiles: [plain_tile(0, 0, 0)], spawn_points: %{}})

      {:ok, view, _html} = live(conn, "/admin/maps/#{map.id}/edit-tiles")

      view |> element("button[phx-value-tool=\"terrain\"]") |> render_click()
      view |> element("[phx-value-target_position=\"0_0_0\"]") |> render_click()
      view |> element("button[phx-click=\"save\"]") |> render_click()

      updated = Game.Maps.get_map!(map.id)
      assert Enum.find(updated.tiles, &(&1["q"] == 0 and &1["r"] == 0 and &1["s"] == 0)) == nil
    end

    test "wall tool on existing terrain tile adds a wall", %{conn: conn} do
      {:ok, map} =
        Game.Maps.create_map(%{slug: "editor_test_wall_add", display_name: "Wall Add",
          tiles: [plain_tile(0, 0, 0)], spawn_points: %{}})

      {:ok, view, _html} = live(conn, "/admin/maps/#{map.id}/edit-tiles")

      view |> element("[phx-value-target_position=\"0_0_0\"]") |> render_click()
      view |> element("button[phx-click=\"save\"]") |> render_click()

      updated = Game.Maps.get_map!(map.id)
      tile = Enum.find(updated.tiles, &(&1["q"] == 0 and &1["r"] == 0 and &1["s"] == 0))
      assert tile != nil
      assert Enum.any?(tile["objects"], &(&1["type"] == "wall"))
    end

    test "wall tool on OOB tile does nothing", %{conn: conn} do
      {:ok, map} =
        Game.Maps.create_map(%{slug: "editor_test_wall_oob", display_name: "Wall OOB",
          tiles: [], spawn_points: %{}})

      {:ok, view, _html} = live(conn, "/admin/maps/#{map.id}/edit-tiles")

      view |> element("[phx-value-target_position=\"0_0_0\"]") |> render_click()
      view |> element("button[phx-click=\"save\"]") |> render_click()

      updated = Game.Maps.get_map!(map.id)
      assert updated.tiles == []
    end

    test "wall tool removes wall from existing terrain tile", %{conn: conn} do
      {:ok, map} =
        Game.Maps.create_map(%{slug: "editor_test_wall_remove", display_name: "Wall Remove",
          tiles: [%{"q" => 0, "r" => 0, "s" => 0, "terrain" => "plain", "objects" => [%{"type" => "wall"}]}],
          spawn_points: %{}})

      {:ok, view, _html} = live(conn, "/admin/maps/#{map.id}/edit-tiles")

      view |> element("[phx-value-target_position=\"0_0_0\"]") |> render_click()
      view |> element("button[phx-click=\"save\"]") |> render_click()

      updated = Game.Maps.get_map!(map.id)
      tile = Enum.find(updated.tiles, &(&1["q"] == 0 and &1["r"] == 0 and &1["s"] == 0))
      refute Enum.any?(tile["objects"] || [], &(&1["type"] == "wall"))
    end
  end
end
