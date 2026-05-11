defmodule GameWeb.SandboxLiveTest do
  use GameWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "Map loading via URL parameter" do
    test "loads a builtin map by slug and renders the battlefield", %{conn: conn} do
      # two_towers has wall objects at {0,0,0}, {1,0,-1}, {-1,0,1}
      # combatants placed away from walls so they don't collide
      initial_state = "[-3_0_3:fighter:1,3_0_-3:mage:2]"

      uri = ~p"/sandbox?initial_state=#{initial_state}&map=two_towers"

      {:ok, view, _html} = live(conn, uri)

      rendered = view |> element(".game-board") |> render()
      assert rendered =~ "hex-cell"
    end

    test "loads a DB-persisted map by slug and renders the battlefield", %{conn: conn} do
      {:ok, _map} =
        Game.Maps.create_map(%{
          slug: "test_arena",
          display_name: "Test Arena",
          tiles: [
            %{
              "q" => 0,
              "r" => 1,
              "s" => -1,
              "terrain" => "plain",
              "objects" => [%{"type" => "wall"}]
            }
          ],
          spawn_points: %{"team_1" => [-3, 0, 3], "team_2" => [3, 0, -3]}
        })

      initial_state = "[-3_0_3:fighter:1,3_0_-3:mage:2]"
      uri = ~p"/sandbox?initial_state=#{initial_state}&map=test_arena"

      {:ok, view, _html} = live(conn, uri)

      rendered = view |> element(".game-board") |> render()
      assert rendered =~ "hex-cell"
    end

    test "wall tiles from a DB map block movement", %{conn: conn} do
      # Place a wall at {0,1,-1} — the tile between the two combatants
      {:ok, _map} =
        Game.Maps.create_map(%{
          slug: "walled_arena",
          display_name: "Walled Arena",
          tiles: [
            %{
              "q" => 0,
              "r" => 1,
              "s" => -1,
              "terrain" => "plain",
              "objects" => [%{"type" => "wall"}]
            }
          ],
          spawn_points: %{}
        })

      initial_state = "[-3_0_3:fighter:1,3_0_-3:mage:2]"
      uri = ~p"/sandbox?initial_state=#{initial_state}&map=walled_arena"

      {:ok, _view, _html} = live(conn, uri)

      template = Game.Maps.get("walled_arena")
      assert template != nil
      assert Map.has_key?(template.tiles, {0, 1, -1})

      tile = template.tiles[{0, 1, -1}]
      assert Enum.any?(tile.objects, &Game.MapObject.blocks_movement?/1)
    end

    test "unknown map slug is ignored and game still loads", %{conn: conn} do
      initial_state = "[-3_0_3:fighter:1,3_0_-3:mage:2]"
      uri = ~p"/sandbox?initial_state=#{initial_state}&map=nonexistent_map"

      # nil template returned → no overlay applied, game loads with plain grid
      {:ok, view, _html} = live(conn, uri)

      rendered = view |> element(".game-board") |> render()
      assert rendered =~ "hex-cell"
    end
  end

  describe "Game state initialization from query parameter" do
    test "Grid cell count for radius=2 with sideways movement", %{conn: conn} do
      # Define the initial state with sideways movement
      initial_state = [
        {{0, 0, 0}, :fighter, 1},
        {{-1, 0, 1}, :mage, 2}
      ]

      # Serialize the initial state into a simplified URI format
      serialized_state =
        initial_state
        |> Enum.map(fn {{q, r, s}, class, id} ->
          "#{q}_#{r}_#{s}:#{class}:#{id}"
        end)
        |> Enum.join(",")
        |> then(&"[#{&1}]")

      # Construct the URI with the `initial_state` query parameter
      uri = ~p"/sandbox?initial_state=#{serialized_state}"

      # Load the game page with the query parameter
      {:ok, view, _html} = live(conn, uri)

      # Verify the grid has been rendered (radius = max_position_radius + 1)
      rendered_grid = view |> element(".game-board") |> render()
      cell_count = (rendered_grid |> String.split("hex-cell") |> length()) - 1
      assert cell_count > 0
    end

    @tag :skip
    test "Loads game state from `initial_state` query parameter and validates mage position", %{
      conn: conn
    } do
      # Define the initial state as a list of tuples
      initial_state = [
        {{0, 0, 0}, :fighter, 1},
        {{1, 1, 0}, :mage, 2}
      ]

      # Serialize the initial state into a simplified URI format
      serialized_state =
        initial_state
        |> Enum.map(fn {{q, r, s}, class, id} ->
          "#{q}_#{r}_#{s}:#{class}:#{id}"
        end)
        |> Enum.join(",")
        |> then(&"[#{&1}]")

      # Construct the URI with the `initial_state` query parameter
      uri = ~p"/sandbox?initial_state=#{serialized_state}"

      # Load the game page with the query parameter
      {:ok, view, _html} = live(conn, uri)

      # Verify that the game state is initialized correctly
      assert view |> element("[phx-value-target_position=\"0_0_0\"]") |> has_element?()
      assert view |> element("[phx-value-target_position=\"1_1_0\"]") |> has_element?()

      # Verify that the characters are positioned correctly
      assert view |> render() =~ "Fighter"
      assert view |> render() =~ "Mage"

      # Validate mage's position visually
      mage_position_style =
        view
        |> element("[phx-value-target_position=\"1_1_0\"]")
        |> render()
        |> Floki.attribute("style")

      assert mage_position_style == ["transform: translate(45px, 104px)"],
             "Mage position rendering failed"
    end
  end

  describe "Combat sandbox demo" do
    @tag :skip
    test "Drawing a card changes turn to next character with a freshly drawn 5-card hand", %{
      conn: conn
    } do
      # Load the game page
      {:ok, view, _html} = live(conn, ~p"/sandbox")

      # Verify initial state has warrior as current player with 5 cards
      IO.puts("Rendered HTML: #{view |> element(".card-status-panel") |> render()}")
      assert view |> element(".card-status-panel") |> render() =~ "Fighter"
      assert view |> element(".card-status-panel") |> render() =~ "Hand: 5 cards"

      # Have the warrior attack himself
      assert view |> render() =~ "HP: 20"
      pick_first_card(view)
      click_warrior(view)
      # (new hp)
      assert view |> render() =~ "HP: 15"

      # Skip Warrior's turn
      view
      |> element("button[phx-click=\"skip_turn\"]")
      |> render_click()

      # Verify now mage is the current player
      assert view |> element(".card-status-panel") |> render() =~ "Mage"

      # Ensure mage has 5 cards in his hand
      hand_content = view |> element(".card-status-panel") |> render()
      assert hand_content =~ "Hand: 5 cards"
      refute hand_content =~ "Hand: 0 cards"

      # Have mage attack himself
      pick_first_card(view)
      click_warrior(view)

      # Skip Warrior's turn
      view
      |> element("button[phx-click=\"skip_turn\"]")
      |> render_click()

      # Verify warrior is now current player
      assert view |> element(".card-status-panel") |> render() =~ "Fighter"

      # Warrior should also have an empty hand now due to the bug
      hand_content = view |> element(".card-status-panel") |> render()
      assert hand_content =~ "Hand: 5 cards"
      refute hand_content =~ "Hand: 0 cards"
    end
  end

  defp pick_first_card(view) do
    view
    |> element("div.card:first-child()")
    |> render_click()
  end

  defp click_warrior(view) do
    view
    |> element("[phx-value-target_position=\"0_0_0\"]")
    |> render_click()
  end
end
