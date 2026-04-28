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
      assert updated_html1 =~ "Both players connected"
    end

    test "single player lobby shows waiting status", %{conn1: conn1, user1: user1} do
      {:ok, view, _html} = live(conn1, ~p"/multiplayer")
      view |> element("button[phx-click='create_lobby']") |> render_click()
      {lobby_path, _flash} = assert_redirect(view)

      {:ok, lobby_view, _html} = live(conn1, lobby_path)

      html = render(lobby_view)
      assert html =~ user1.email
      assert html =~ "Waiting for opponent"
    end

    test "navigating to nonexistent lobby redirects to /multiplayer", %{conn1: conn1} do
      assert {:error, {:live_redirect, %{to: "/multiplayer"}}} =
               live(conn1, ~p"/multiplayer/doesnotexist00")
    end

    test "full lobby rejects third player", %{conn1: conn1, conn2: conn2} do
      user3 = Game.AccountsFixtures.user_fixture()
      conn3 = Phoenix.ConnTest.build_conn() |> log_in_user(user3)

      {:ok, view1, _} = live(conn1, ~p"/multiplayer")
      view1 |> element("button[phx-click='create_lobby']") |> render_click()
      {lobby_path, _} = assert_redirect(view1)

      {:ok, _lobby_view1, _} = live(conn1, lobby_path)
      {:ok, _lobby_view2, _} = live(conn2, lobby_path)

      assert {:error, {:live_redirect, %{to: "/multiplayer"}}} = live(conn3, lobby_path)
    end
  end

  describe "LobbyLive - ready state" do
    setup :two_players_in_lobby

    test "player1 toggles ready, player2's view shows player1 as ready", %{
      lobby_view1: lobby_view1,
      lobby_view2: lobby_view2,
      user1: user1
    } do
      lobby_view1 |> element("button[phx-click='toggle_ready']") |> render_click()

      html2 = render(lobby_view2)
      assert html2 =~ user1.email
      assert html2 =~ "ready"
    end
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
