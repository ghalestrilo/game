defmodule GameWeb.SandboxSetupLiveTest do
  use GameWeb.ConnCase

  import Phoenix.LiveViewTest

  test "renders setup page", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/sandbox/setup")
    assert html =~ "Sandbox Setup"
    assert html =~ "Add a character"
  end

  test "selecting a class adds it to the character list", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sandbox/setup")

    view |> form("form[phx-change=add_character]", %{class: "fighter"}) |> render_change()

    assert view |> render() =~ "fighter"
  end

  test "removing a character removes it from the list", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sandbox/setup")

    view |> form("form[phx-change=add_character]", %{class: "fighter"}) |> render_change()
    view |> form("form[phx-change=add_character]", %{class: "mage"}) |> render_change()

    view |> element("button[phx-value-index='0']") |> render_click()

    html = view |> render()
    refute html =~ "team 2"
  end

  test "start is disabled with fewer than 2 characters", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sandbox/setup")

    view |> form("form[phx-change=add_character]", %{class: "fighter"}) |> render_change()

    assert view |> element("button[phx-click=start_sandbox]") |> render() =~ "disabled"
  end

  test "start navigates to sandbox with characters param", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sandbox/setup")

    view |> form("form[phx-change=add_character]", %{class: "fighter"}) |> render_change()
    view |> form("form[phx-change=add_character]", %{class: "mage"}) |> render_change()

    assert {:error, {:live_redirect, %{to: to}}} =
             view |> element("button[phx-click=start_sandbox]") |> render_click()

    assert to =~ "/sandbox"
    assert to =~ "characters=fighter%2Cmage" or to =~ "characters=fighter,mage"
  end
end
