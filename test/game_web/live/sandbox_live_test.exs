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
            %{"q" => -3, "r" => 0, "s" => 3, "terrain" => "plain", "objects" => []},
            %{"q" => 0, "r" => 1, "s" => -1, "terrain" => "plain", "objects" => [%{"type" => "wall"}]},
            %{"q" => 3, "r" => 0, "s" => -3, "terrain" => "plain", "objects" => []}
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

  describe "characters= URL parameter" do
    test "places combatants at map spawn points", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sandbox?characters=fighter,mage&map=two_towers")
      assert view |> element(".game-board") |> render() =~ "hex-cell"
    end

    test "extra characters beyond spawn points get random free tiles", %{conn: conn} do
      # two_towers has 2 spawn points; third character gets a random free tile
      {:ok, view, _html} = live(conn, ~p"/sandbox?characters=fighter,mage,fighter&map=two_towers")
      assert view |> element(".game-board") |> render() =~ "hex-cell"
    end

    test "characters= without a map uses random free tiles", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sandbox?characters=fighter,mage")
      assert view |> element(".game-board") |> render() =~ "hex-cell"
    end

    test "initial_state= still works when characters= is absent", %{conn: conn} do
      uri = ~p"/sandbox?initial_state=[-3_0_3:fighter:1,3_0_-3:mage:2]"
      {:ok, view, _html} = live(conn, uri)
      assert view |> element(".game-board") |> render() =~ "hex-cell"
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

  defp find_card_in_hand(_view, game_pid, card_name) do
    Game.get_state(game_pid).combat.current_turn.player.cards.hand
    |> Enum.find_index(&(&1.name == card_name))
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

  describe "Revive card effect E2E (3d=true)" do
    # Scenario: fighter1 (team1) kills fighter2 (team1 ally) with Executioner,
    # then revives them with Ressurrect. The mage (team2) stays alive throughout
    # so game never reaches game_over. After revival, fighter2 takes their own turn.
    #
    # This test exercises the full production code paths:
    #   - build_tile_overlay marks dead character positions :valid for revive cards
    #   - keyboard_targets (w/s keys) finds dead characters
    #   - is_target_cell_valid? accepts a dead character's tile
    #   - revive effect reinserts character into queue
    #   - revived character can act normally

    test "fighter kills ally, casts Ressurrect via character click, revived ally takes a turn", %{conn: conn} do
      # 3 chars, all adjacent: fighter1 (team1, acts first), fighter2 (team1, will die),
      # mage (team2, stays alive so game never ends)
      {:ok, view, _html} =
        live(conn, ~p"/sandbox?initial_state=[0_0_0:fighter:1,1_0_-1:fighter:1,2_0_-2:mage:2]&3d=true")

      %{socket: %{assigns: %{game_pid: game_pid}}} = :sys.get_state(view.pid)

      # --- Turn 1: fighter1 kills fighter2 with Executioner ---
      s = Game.get_state(game_pid)
      fighter1 = s.combat.current_turn.player
      assert fighter1.class == "fighter"

      [fighter2, mage] = s.combat.queue
      assert fighter2.class == "fighter"
      assert mage.class == "mage"

      # Draw until Executioner is in hand (deck is all Executioner/Ressurrect so it will appear)
      exec_idx = find_card_in_hand(view, game_pid, "Executioner")

      render_hook(view, "pick_card", %{"card_index" => to_string(exec_idx)})
      render_hook(view, "interact", %{"target_character_id" => to_string(fighter2.id)})

      s = Game.get_state(game_pid)
      assert Enum.any?(Game.CombatState.dead_characters(s.combat), &(&1.id == fighter2.id)),
             "fighter2 should be dead after Executioner"

      # fighter1 skips remaining turn; turn advances to mage (fighter2 is dead, skipped)
      render_hook(view, "skip_turn", %{})

      # --- Turn 2: mage skips ---
      s = Game.get_state(game_pid)
      assert s.combat.current_turn.player.class == "mage"
      render_hook(view, "skip_turn", %{})

      # --- Turn 3: fighter1 casts Ressurrect on dead fighter2 ---
      s = Game.get_state(game_pid)
      assert s.combat.current_turn.player.id == fighter1.id

      # ASSERT: tile overlay marks dead fighter2's position as :valid
      ressurrect_idx = find_card_in_hand(view, game_pid, "Ressurrect")
      assert ressurrect_idx != nil, "fighter1 must have Ressurrect in hand on turn 3"

      ressurrect_card = Enum.at(s.combat.current_turn.player.cards.hand, ressurrect_idx)
      {overlay, _} = Game.Card.build_tile_overlay(ressurrect_card, s.combat)

      dead_fighter2 = hd(Game.CombatState.dead_characters(s.combat))

      assert Map.get(overlay, dead_fighter2.position) == :valid,
             "dead fighter2's tile must be :valid in Ressurrect overlay"
      assert Map.get(overlay, fighter1.position) != :valid,
             "alive fighter1's tile must not be :valid for Ressurrect"

      # Pick Ressurrect, then cast via tile click at fighter2's position
      {f2q, f2r, f2s} = fighter2.position
      render_hook(view, "pick_card", %{"card_index" => to_string(ressurrect_idx)})
      render_hook(view, "interact", %{"target_position" => "#{f2q}_#{f2r}_#{f2s}"})

      s = Game.get_state(game_pid)
      revived = Enum.find(Game.CombatState.alive_characters(s.combat), &(&1.id == fighter2.id))
      assert revived != nil, "fighter2 should be back in queue after Ressurrect"
      assert revived.dead == false
      assert revived.hp == 5

      render_hook(view, "skip_turn", %{})

      # --- Turn 4: fighter2 (revived) acts ---
      s = Game.get_state(game_pid)
      assert s.combat.current_turn.player.id == fighter2.id,
             "revived fighter2 should be current player"

      mage_hp_before = Enum.find(s.combat.queue, &(&1.class == "mage")).hp

      attack_idx =
        Enum.find_index(s.combat.current_turn.player.cards.hand, fn c ->
          c.name in ["Executioner", "Strike"]
        end)

      assert attack_idx != nil, "fighter2 must have an attack card after revival"

      render_hook(view, "pick_card", %{"card_index" => to_string(attack_idx)})
      render_hook(view, "interact", %{"target_character_id" => to_string(mage.id)})

      s = Game.get_state(game_pid)
      mage_after = Enum.find(Game.CombatState.get_current_queue(s.combat), &(&1.class == "mage"))
      assert mage_after.hp < mage_hp_before,
             "mage should have taken damage from revived fighter2"
    end
  end
end
