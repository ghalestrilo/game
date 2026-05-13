defmodule GameWeb.Admin.MapEditorLiveTest do
  use GameWeb.ConnCase

  import Phoenix.LiveViewTest

  setup :register_and_log_in_admin

  describe "map editor" do
    test "renders the game board for a map with no tiles", %{conn: conn} do
      {:ok, map} =
        Game.Maps.create_map(%{
          slug: "editor_test_empty",
          display_name: "Editor Test Empty",
          tiles: [],
          spawn_points: %{}
        })

      {:ok, _view, html} = live(conn, "/admin/maps/#{map.id}/edit-map")

      assert html =~ "game-board"
      assert html =~ "hex-cell"
    end

    test "renders the game board for a map with existing wall tiles", %{conn: conn} do
      {:ok, map} =
        Game.Maps.create_map(%{
          slug: "editor_test_walls",
          display_name: "Editor Test Walls",
          tiles: [
            %{"q" => 0, "r" => 0, "s" => 0, "terrain" => "plain", "objects" => [%{"type" => "wall"}]}
          ],
          spawn_points: %{}
        })

      {:ok, _view, html} = live(conn, "/admin/maps/#{map.id}/edit-map")

      assert html =~ "game-board"
      assert html =~ "hex-cell"
    end

    test "clicking a plain tile adds a wall", %{conn: conn} do
      {:ok, map} =
        Game.Maps.create_map(%{
          slug: "editor_test_toggle_on",
          display_name: "Editor Test Toggle On",
          tiles: [],
          spawn_points: %{}
        })

      {:ok, view, _html} = live(conn, "/admin/maps/#{map.id}/edit-map")

      view
      |> element("[phx-value-target_position=\"0_0_0\"]")
      |> render_click()

      updated = Game.Maps.get_map!(map.id)
      tile = Enum.find(updated.tiles, &(&1["q"] == 0 and &1["r"] == 0 and &1["s"] == 0))
      assert tile != nil
      assert Enum.any?(tile["objects"], &(&1["type"] == "wall"))
    end

    test "clicking a wall tile removes the wall", %{conn: conn} do
      {:ok, map} =
        Game.Maps.create_map(%{
          slug: "editor_test_toggle_off",
          display_name: "Editor Test Toggle Off",
          tiles: [
            %{"q" => 0, "r" => 0, "s" => 0, "terrain" => "plain", "objects" => [%{"type" => "wall"}]}
          ],
          spawn_points: %{}
        })

      {:ok, view, _html} = live(conn, "/admin/maps/#{map.id}/edit-map")

      view
      |> element("[phx-value-target_position=\"0_0_0\"]")
      |> render_click()

      updated = Game.Maps.get_map!(map.id)
      tile = Enum.find(updated.tiles, &(&1["q"] == 0 and &1["r"] == 0 and &1["s"] == 0))
      refute Enum.any?(tile["objects"] || [], &(&1["type"] == "wall"))
    end
  end
end
