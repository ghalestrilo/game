defmodule GameWeb.LobbyLiveTest do
  use GameWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  describe "MultiplayerLive" do
    setup :register_and_log_in_user

    test "renders create lobby button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/multiplayer")
      assert html =~ "Create Lobby"
    end

    test "create lobby redirects to lobby page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/multiplayer")

      view |> element("button[phx-click='create_lobby']") |> render_click()

      {path, _flash} = assert_redirect(view)
      assert path =~ ~r|/multiplayer/[a-f0-9]+|
    end

    test "unauthenticated user is redirected to log-in", %{} do
      unauthed_conn = Phoenix.ConnTest.build_conn()

      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(unauthed_conn, ~p"/multiplayer")
    end
  end

  describe "LobbyLive - two player scenario" do
    setup :two_players_in_lobby

    test "user1 creates lobby, user2 joins, both see both players", %{
      lobby_view1: lobby_view1,
      lobby_view2: _lobby_view2,
      user1: user1,
      user2: user2
    } do
      updated_html1 = render(lobby_view1)
      assert updated_html1 =~ user1.email
      assert updated_html1 =~ user2.email
      assert updated_html1 =~ "Players connected"
    end

    test "single player lobby shows waiting status", %{conn1: conn1, user1: user1} do
      {:ok, view, _html} = live(conn1, ~p"/multiplayer")
      view |> element("button[phx-click='create_lobby']") |> render_click()
      {lobby_path, _flash} = assert_redirect(view)

      {:ok, lobby_view, _html} = live(conn1, lobby_path)

      html = render(lobby_view)
      assert html =~ user1.email
      assert html =~ "Waiting for players"
    end

    test "navigating to nonexistent lobby redirects to /multiplayer", %{conn1: conn1} do
      assert {:error, {:live_redirect, %{to: "/multiplayer"}}} =
               live(conn1, ~p"/multiplayer/doesnotexist00")
    end

    test "lobby allows up to 8 players", %{conn1: conn1, conn2: conn2} do
      {:ok, view1, _} = live(conn1, ~p"/multiplayer")
      view1 |> element("button[phx-click='create_lobby']") |> render_click()
      {lobby_path, _} = assert_redirect(view1)

      {:ok, _lobby_view1, _} = live(conn1, lobby_path)
      {:ok, _lobby_view2, _} = live(conn2, lobby_path)

      # Players 3-8 can join successfully
      for _ <- 3..8 do
        extra_user = Game.AccountsFixtures.user_fixture()
        extra_conn = Phoenix.ConnTest.build_conn() |> log_in_user(extra_user)
        assert {:ok, _, _} = live(extra_conn, lobby_path)
      end
    end

    test "lobby rejects 9th player when full (8 players)", %{conn1: conn1, conn2: conn2} do
      {:ok, view1, _} = live(conn1, ~p"/multiplayer")
      view1 |> element("button[phx-click='create_lobby']") |> render_click()
      {lobby_path, _} = assert_redirect(view1)

      {:ok, _lobby_view1, _} = live(conn1, lobby_path)
      {:ok, _lobby_view2, _} = live(conn2, lobby_path)

      # Fill up to 8 players
      for _ <- 3..8 do
        extra_user = Game.AccountsFixtures.user_fixture()
        extra_conn = Phoenix.ConnTest.build_conn() |> log_in_user(extra_user)
        {:ok, _, _} = live(extra_conn, lobby_path)
      end

      # 9th player is rejected
      ninth_user = Game.AccountsFixtures.user_fixture()
      ninth_conn = Phoenix.ConnTest.build_conn() |> log_in_user(ninth_user)
      assert {:error, {:live_redirect, %{to: "/multiplayer"}}} = live(ninth_conn, lobby_path)
    end

    test "lobby is ready with 2 players and waiting with 1", %{conn1: conn1} do
      {:ok, view1, _} = live(conn1, ~p"/multiplayer")
      view1 |> element("button[phx-click='create_lobby']") |> render_click()
      {lobby_path, _} = assert_redirect(view1)

      {:ok, lobby_view1, html1} = live(conn1, lobby_path)
      assert html1 =~ "Waiting for players"

      user2 = Game.AccountsFixtures.user_fixture()
      conn2 = Phoenix.ConnTest.build_conn() |> log_in_user(user2)
      {:ok, _lobby_view2, _} = live(conn2, lobby_path)

      assert render(lobby_view1) =~ "Players connected"
    end

    test "lobby stays ready when a 3rd player joins", %{conn1: conn1, conn2: conn2} do
      {:ok, view1, _} = live(conn1, ~p"/multiplayer")
      view1 |> element("button[phx-click='create_lobby']") |> render_click()
      {lobby_path, _} = assert_redirect(view1)

      {:ok, lobby_view1, _} = live(conn1, lobby_path)
      {:ok, _lobby_view2, _} = live(conn2, lobby_path)

      user3 = Game.AccountsFixtures.user_fixture()
      conn3 = Phoenix.ConnTest.build_conn() |> log_in_user(user3)
      {:ok, _lobby_view3, html3} = live(conn3, lobby_path)

      assert html3 =~ "Players connected"
      assert render(lobby_view1) =~ "Players connected"
    end

    test "lobby reverts to waiting when player count drops below 2", %{
      conn1: conn1,
      conn2: conn2,
      user2: user2
    } do
      {:ok, view1, _} = live(conn1, ~p"/multiplayer")
      view1 |> element("button[phx-click='create_lobby']") |> render_click()
      {lobby_path, _} = assert_redirect(view1)

      {:ok, lobby_view1, _} = live(conn1, lobby_path)
      {:ok, _lobby_view2, _} = live(conn2, lobby_path)

      assert render(lobby_view1) =~ "Players connected"

      lobby_id = lobby_path |> String.split("/") |> List.last()
      Game.Lobby.leave(lobby_id, user2.id)

      assert render(lobby_view1) =~ "Waiting for players"
    end
  end

  describe "LobbyLive - ready state" do
    setup :two_players_in_lobby

    defp select_class(view, class) do
      view |> element("form[phx-change='select_class']") |> render_change(%{"class" => class})
    end

    test "player1 toggles ready, player2's view shows player1 as ready", %{
      lobby_view1: lobby_view1,
      lobby_view2: lobby_view2,
      user1: user1
    } do
      select_class(lobby_view1, "fighter")
      lobby_view1 |> element("button[phx-click='toggle_ready']") |> render_click()

      html2 = render(lobby_view2)
      assert html2 =~ user1.email
      assert html2 =~ "ready"
    end

    test "player1 selects a class, player2's view shows that class", %{
      lobby_view1: lobby_view1,
      lobby_view2: lobby_view2,
      user1: user1
    } do
      select_class(lobby_view1, "fighter")

      html2 = render(lobby_view2)
      assert html2 =~ user1.email
      assert html2 =~ "fighter"
    end

    test "player1's own view shows selected class immediately", %{
      lobby_view1: lobby_view1,
      user1: user1
    } do
      html = select_class(lobby_view1, "fighter")

      assert html =~ user1.email
      assert html =~ "fighter"
    end

    test "dropdown retains selected class after re-render", %{lobby_view1: lobby_view1} do
      select_class(lobby_view1, "fighter")

      html = render(lobby_view1)
      assert html =~ ~s(value="fighter" selected)
    end

    test "ready button is disabled until a class is selected", %{lobby_view1: lobby_view1} do
      assert lobby_view1
             |> element("button[phx-click='toggle_ready'][disabled]")
             |> has_element?()

      select_class(lobby_view1, "fighter")

      refute lobby_view1
             |> element("button[phx-click='toggle_ready'][disabled]")
             |> has_element?()
    end

    test "cannot toggle ready without a class selected", %{lobby_view1: lobby_view1} do
      assert lobby_view1
             |> element("button[phx-click='toggle_ready'][disabled]")
             |> has_element?()
    end
  end

  describe "LobbyLive - team selection" do
    setup :two_players_in_lobby

    defp select_team(view, team) do
      view |> element("form[phx-change='select_team']") |> render_change(%{"team" => team})
    end

    test "players default to different teams", %{
      lobby_view1: lobby_view1,
      lobby_view2: lobby_view2
    } do
      html1 = render(lobby_view1)
      html2 = render(lobby_view2)
      assert html1 =~ "Team 1"
      assert html2 =~ "Team 2"
    end

    test "select_team updates team visible to all", %{
      lobby_view1: lobby_view1,
      lobby_view2: lobby_view2,
      user1: user1
    } do
      select_team(lobby_view1, "Alpha")

      html2 = render(lobby_view2)
      assert html2 =~ user1.email
      assert html2 =~ "Alpha"
    end

    test "game does not start when all players on same team", %{
      lobby_view1: lobby_view1,
      lobby_view2: lobby_view2
    } do
      select_team(lobby_view2, "1")

      select_class(lobby_view1, "fighter")
      select_class(lobby_view2, "fighter")

      lobby_view1 |> element("button[phx-click='toggle_ready']") |> render_click()
      lobby_view2 |> element("button[phx-click='toggle_ready']") |> render_click()

      refute_redirected(lobby_view1)
      refute_redirected(lobby_view2)
    end

    test "game starts when players are on different teams", %{
      lobby_view1: lobby_view1,
      lobby_view2: lobby_view2
    } do
      select_class(lobby_view1, "fighter")
      select_class(lobby_view2, "fighter")

      lobby_view1 |> element("button[phx-click='toggle_ready']") |> render_click()
      lobby_view2 |> element("button[phx-click='toggle_ready']") |> render_click()

      {path, _} = assert_redirect(lobby_view1)
      assert path =~ ~r|/multiplayer/.+/play|
    end
  end

  describe "LobbyLive - booster packs lobby settings" do
    setup :two_players_in_lobby

    test "host sees booster count input, non-host sees read-only badge", %{
      lobby_view1: lobby_view1,
      lobby_view2: lobby_view2
    } do
      assert lobby_view1 |> element("form[phx-change='set_boosters']") |> has_element?()
      refute lobby_view2 |> element("form[phx-change='set_boosters']") |> has_element?()
    end

    test "setting booster count broadcasts to all players", %{
      lobby_view1: lobby_view1,
      lobby_view2: lobby_view2
    } do
      set_boosters(lobby_view1, 3)
      assert render(lobby_view2) =~ "3"
    end
  end

  describe "LobbyLive - booster packs in-game" do
    setup :two_players_in_lobby_with_boosters

    test "each player sees their own booster modal independently", %{
      game_view1: game_view1,
      game_view2: game_view2
    } do
      assert render(game_view1) =~ "Booster Pack"
      assert render(game_view2) =~ "Booster Pack"
    end

    test "picking a booster card does not advance the other player's booster", %{
      game_view1: game_view1,
      game_view2: game_view2
    } do
      # Player 1 picks from their booster (2 packs configured, so 1 remaining after pick)
      game_view1 |> element("[phx-value-card_index='0']") |> render_click()
      assert render(game_view1) =~ "1 pack(s) remaining"

      # Player 2's booster is unaffected — still on their first pack (2 remaining)
      assert render(game_view2) =~ "2 pack(s) remaining"
    end

    @tag booster_count: 1
    test "after all boosters picked, combat view is shown", %{
      game_view1: game_view1,
      game_view2: game_view2
    } do
      # Each player picks their single booster card
      game_view1 |> element("[phx-value-card_index='0']") |> render_click()
      game_view2 |> element("[phx-value-card_index='0']") |> render_click()

      refute render(game_view1) =~ "Booster Pack"
      refute render(game_view2) =~ "Booster Pack"
      assert render(game_view1) =~ "game-board"
      assert render(game_view2) =~ "game-board"
    end

    test "booster cards appear in the player's deck in combat", %{
      game_view1: game_view1,
      game_view2: game_view2,
      game_pid: game_pid,
      user1: user1
    } do
      # seed_base_classes gives fighters a 10-card Strike deck (5 in hand, 5 in draw).
      # Pick 2 booster cards — total should increase by 2.
      before = Game.get_state(game_pid)

      # Find the player whose booster we're controlling via game_view1.
      # current_player is set to the user's character during PvP mount.
      # We identify them by matching the user id against the booster_state keys.
      player1_id = Enum.find(Map.keys(before.booster_state), &(to_string(&1) == to_string(user1.id)))

      assert player1_id != nil,
             "user1 (id=#{user1.id}) not found in booster_state keys: #{inspect(Map.keys(before.booster_state))}"

      # Player may be in queue OR in current_turn (the active player is popped from queue).
      player1_before =
        Enum.find(before.combat.queue, &(to_string(&1.id) == to_string(player1_id))) ||
          (before.combat.current_turn.player &&
             to_string(before.combat.current_turn.player.id) == to_string(player1_id) &&
             before.combat.current_turn.player)

      assert player1_before != nil,
             "player1 not found in queue or current_turn for id #{player1_id}"

      cards_before =
        length(player1_before.cards.draw) +
          length(player1_before.cards.hand) +
          length(player1_before.cards.discard)

      game_view1 |> element("[phx-value-card_index='0']") |> render_click()
      game_view1 |> element("[phx-value-card_index='0']") |> render_click()
      # player 2 also finishes so combat starts
      game_view2 |> element("[phx-value-card_index='0']") |> render_click()
      game_view2 |> element("[phx-value-card_index='0']") |> render_click()

      after_state = Game.get_state(game_pid)

      player1_after =
        Enum.find(after_state.combat.queue, &(to_string(&1.id) == to_string(player1_id))) ||
          (after_state.combat.current_turn.player &&
             to_string(after_state.combat.current_turn.player.id) == to_string(player1_id) &&
             after_state.combat.current_turn.player)

      assert player1_after != nil, "player1 not found in queue or current_turn after boosters"

      cards_after =
        length(player1_after.cards.draw) +
          length(player1_after.cards.hand) +
          length(player1_after.cards.discard)

      assert cards_after == cards_before + 2,
             "Expected #{cards_before + 2} cards after 2 boosters, got #{cards_after}"
    end
  end

  defp set_boosters(view, count) do
    view
    |> element("form[phx-change='set_boosters']")
    |> render_change(%{"boosters" => to_string(count)})
  end

  defp two_players_in_lobby_with_boosters(%{booster_count: booster_count} = context),
    do: do_two_players_in_lobby_with_boosters(context, booster_count)

  defp two_players_in_lobby_with_boosters(context),
    do: do_two_players_in_lobby_with_boosters(context, 2)

  defp do_two_players_in_lobby_with_boosters(context, booster_count) do
    base = two_players_in_lobby(context)
    %{lobby_view1: lobby_view1, lobby_view2: lobby_view2, conn1: conn1, conn2: conn2} = base

    set_boosters(lobby_view1, booster_count)

    # Start the game
    lobby_view1
    |> element("form[phx-change='select_class']")
    |> render_change(%{"class" => "fighter"})

    lobby_view2
    |> element("form[phx-change='select_class']")
    |> render_change(%{"class" => "fighter"})

    lobby_view1 |> element("button[phx-click='toggle_ready']") |> render_click()
    lobby_view2 |> element("button[phx-click='toggle_ready']") |> render_click()

    {play_path1, _} = assert_redirect(lobby_view1)
    {play_path2, _} = assert_redirect(lobby_view2)

    {:ok, game_view1, _} = live(conn1, play_path1)
    {:ok, game_view2, _} = live(conn2, play_path2)

    lobby_id = play_path1 |> String.split("/") |> Enum.at(-2)
    {:ok, %{game_pid: game_pid}} = Game.Lobby.get(lobby_id)

    Map.merge(base, %{
      game_view1: game_view1,
      game_view2: game_view2,
      game_pid: game_pid,
      booster_count: booster_count
    })
  end

  defp two_players_in_lobby(context) do
    user1 = Game.AccountsFixtures.user_fixture()
    user2 = Game.AccountsFixtures.user_fixture()
    conn1 = Phoenix.ConnTest.build_conn() |> log_in_user(user1)
    conn2 = Phoenix.ConnTest.build_conn() |> log_in_user(user2)

    {:ok, view1, _html} = live(conn1, ~p"/multiplayer")
    view1 |> element("button[phx-click='create_lobby']") |> render_click()
    {lobby_path, _flash} = assert_redirect(view1)

    {:ok, lobby_view1, _} = live(conn1, lobby_path)
    {:ok, lobby_view2, _} = live(conn2, lobby_path)

    Map.merge(context, %{
      conn1: conn1,
      conn2: conn2,
      user1: user1,
      user2: user2,
      lobby_path: lobby_path,
      lobby_view1: lobby_view1,
      lobby_view2: lobby_view2
    })
  end
end
