defmodule GameWeb.MultiplayerPlayLiveTest do
  use GameWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  # Brings two players into the lobby with classes selected and both ready,
  # which triggers game start. Returns lobby_path and both lobby views that
  # will have been redirected to /multiplayer/:id/play.
  defp two_players_ready(context) do
    user1 = Game.AccountsFixtures.user_fixture()
    user2 = Game.AccountsFixtures.user_fixture()
    conn1 = Phoenix.ConnTest.build_conn() |> log_in_user(user1)
    conn2 = Phoenix.ConnTest.build_conn() |> log_in_user(user2)

    # User1 creates lobby
    {:ok, view1, _} = live(conn1, ~p"/multiplayer")
    view1 |> element("button[phx-click='create_lobby']") |> render_click()
    {lobby_path, _} = assert_redirect(view1)

    # Both join the lobby
    {:ok, lobby_view1, _} = live(conn1, lobby_path)
    {:ok, lobby_view2, _} = live(conn2, lobby_path)

    # Both select a class
    lobby_view1
    |> element("form[phx-change='select_class']")
    |> render_change(%{"class" => "fighter"})

    lobby_view2
    |> element("form[phx-change='select_class']")
    |> render_change(%{"class" => "mage"})

    # Both toggle ready — second ready triggers game start and redirects both lobby views
    lobby_view1 |> element("button[phx-click='toggle_ready']") |> render_click()
    lobby_view2 |> element("button[phx-click='toggle_ready']") |> render_click()

    {play_path, _} = assert_redirect(lobby_view2)

    Map.merge(context, %{
      conn1: conn1,
      conn2: conn2,
      user1: user1,
      user2: user2,
      lobby_path: lobby_path,
      play_path: play_path
    })
  end

  describe "game start" do
    setup :two_players_ready

    test "both ready triggers redirect to play path", %{play_path: play_path} do
      assert play_path =~ ~r|/multiplayer/[a-f0-9]+/play|
    end

    test "both players can mount the play view and see the combat board", %{
      conn1: conn1,
      conn2: conn2,
      user1: user1,
      user2: user2,
      play_path: play_path
    } do
      {:ok, view1, _} = live(conn1, play_path)
      {:ok, view2, _} = live(conn2, play_path)

      # Both see the combat board with both characters (names default to user emails)
      assert render(view1) =~ user1.email
      assert render(view1) =~ user2.email
      assert render(view2) =~ user1.email
      assert render(view2) =~ user2.email
    end

    test "non-active player gets told it's not their turn", %{
      conn1: conn1,
      conn2: conn2,
      play_path: play_path
    } do
      {:ok, view1, _} = live(conn1, play_path)
      {:ok, view2, _} = live(conn2, play_path)

      # Fighter (user1, team 1) always goes first — user2 (Mage, team 2) is idle
      # Firing pick_card from user2 should be blocked
      render_click(view2, "pick_card", %{"card_index" => "0"})
      assert render(view2) =~ "not your turn"

      # user1 (Fighter) is active — pick_card should not flash an error
      render_click(view1, "pick_card", %{"card_index" => "0"})
      refute render(view1) =~ "not your turn"
    end

    test "game over resets lobby and redirects both players back", %{
      conn1: conn1,
      conn2: conn2,
      play_path: play_path,
      lobby_path: lobby_path
    } do
      {:ok, view1, _} = live(conn1, play_path)
      {:ok, _view2, _} = live(conn2, play_path)

      # Trigger win_match from one session — ends the game
      render_click(view1, "win_match", %{})

      # Both sessions should be redirected back to the lobby
      {redirect_path, _} = assert_redirect(view1)
      assert redirect_path == lobby_path
    end

    test "each player only sees their own hand when it is their turn", %{
      conn1: conn1,
      conn2: conn2,
      play_path: play_path
    } do
      {:ok, view1, _} = live(conn1, play_path)
      {:ok, view2, _} = live(conn2, play_path)

      html1 = render(view1)
      html2 = render(view2)

      # Fighter (user1) goes first — user1 sees the card row, user2 does not
      if html1 =~ "card-row" do
        refute html2 =~ "card-row"
      else
        # Mage (user2) goes first — user2 sees the card row, user1 does not
        assert html2 =~ "card-row"
        refute html1 =~ "card-row"
      end
    end

    test "after game ends lobby shows players unready with classes kept", %{
      conn1: conn1,
      conn2: conn2,
      play_path: play_path,
      lobby_path: lobby_path
    } do
      {:ok, view1, _} = live(conn1, play_path)
      {:ok, _view2, _} = live(conn2, play_path)

      render_click(view1, "win_match", %{})
      assert_redirect(view1)

      # Re-mount the lobby for user1 and use render/1 for the connected state
      {:ok, lobby_view, _} = live(conn1, lobby_path)
      html = render(lobby_view)

      # Classes are preserved
      assert html =~ "fighter"
      assert html =~ "mage"
      # Ready indicators are gone
      refute html =~ ">ready<"
    end

    test "game over redirects both players to lobby without any button click", %{
      conn1: conn1,
      conn2: conn2,
      play_path: play_path,
      lobby_path: lobby_path
    } do
      {:ok, view1, _} = live(conn1, play_path)
      {:ok, view2, _} = live(conn2, play_path)

      render_click(view1, "win_match", %{})

      {redirect1, _} = assert_redirect(view1)
      {redirect2, _} = assert_redirect(view2)
      assert redirect1 == lobby_path
      assert redirect2 == lobby_path
    end

    test "action log: one player's committed action appears in the other player's view", %{
      conn1: conn1,
      conn2: conn2,
      play_path: play_path
    } do
      {:ok, view1, _} = live(conn1, play_path)
      {:ok, view2, _} = live(conn2, play_path)

      # Determine which player is active (fighter goes first, but class assignment order
      # isn't guaranteed, so we detect it from the rendered state).
      {active_view, idle_view} =
        if render(view1) =~ "card-row", do: {view1, view2}, else: {view2, view1}

      # Skip turn — a valid, committed action that always succeeds for the active player.
      render_click(active_view, "skip_turn", %{})

      # The skip action string must appear in the idle player's rendered view,
      # proving the log is shared via the game server rather than being socket-local.
      assert render(idle_view) =~ "skipped their turn"
    end

    test "old game process is stopped after lobby reset", %{
      conn1: conn1,
      conn2: conn2,
      play_path: play_path,
      lobby_path: lobby_path
    } do
      {:ok, view1, _} = live(conn1, play_path)
      {:ok, _view2, _} = live(conn2, play_path)

      lobby_id = lobby_path |> String.split("/") |> List.last()
      {:ok, lobby} = Game.Lobby.get(lobby_id)
      game_pid = lobby.game_pid

      render_click(view1, "win_match", %{})
      assert_redirect(view1)

      refute Process.alive?(game_pid)
    end
  end
end
