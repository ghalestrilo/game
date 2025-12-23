defmodule GameWeb.BaseDeckLiveTest do
  use GameWeb.ConnCase

  import Phoenix.LiveViewTest
  import Game.BaseDecksFixtures

  @create_attrs %{name: "new deck name"}
  @update_attrs %{name: "some updated name"}
  @invalid_attrs %{name: nil}

  defp create_base_deck(_) do
    base_deck = base_deck_fixture()
    %{base_deck: base_deck}
  end

  describe "Index" do
    setup [:create_base_deck]

    test "lists all basedecks", %{conn: conn, base_deck: base_deck} do
      {:ok, _index_live, html} = live(conn, ~p"/admin/basedecks")

      assert html =~ "Listing Basedecks"
      assert html =~ base_deck.name
    end

    test "saves new base_deck", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/basedecks")

      assert index_live |> element("a", "New Base deck") |> render_click() =~
               "New Base deck"

      assert_patch(index_live, ~p"/admin/basedecks/new")

      assert index_live
             |> form("#base_deck-form", base_deck: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#base_deck-form", base_deck: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/admin/basedecks")

      html = render(index_live)
      assert html =~ "Base deck created successfully"
      assert html =~ "new deck name"
    end

    test "updates base_deck in listing", %{conn: conn, base_deck: base_deck} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/basedecks")

      assert index_live |> element("#basedecks-#{base_deck.id} a", "Edit") |> render_click() =~
               "Edit Base deck"

      assert_patch(index_live, ~p"/admin/basedecks/#{base_deck}/edit")

      assert index_live
             |> form("#base_deck-form", base_deck: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#base_deck-form", base_deck: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/admin/basedecks")

      html = render(index_live)
      assert html =~ "Base deck updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes base_deck in listing", %{conn: conn, base_deck: base_deck} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/basedecks")

      assert index_live |> element("#basedecks-#{base_deck.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#basedecks-#{base_deck.id}")
    end
  end

  describe "Show" do
    setup [:create_base_deck]

    test "displays base_deck", %{conn: conn, base_deck: base_deck} do
      {:ok, _show_live, html} = live(conn, ~p"/admin/basedecks/#{base_deck}")

      assert html =~ "Show Base deck"
      assert html =~ base_deck.name
    end

    test "updates base_deck within modal", %{conn: conn, base_deck: base_deck} do
      {:ok, show_live, _html} = live(conn, ~p"/admin/basedecks/#{base_deck}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Base deck"

      assert_patch(show_live, ~p"/admin/basedecks/#{base_deck}/show/edit")

      assert show_live
             |> form("#base_deck-form", base_deck: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#base_deck-form", base_deck: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/admin/basedecks/#{base_deck}")

      html = render(show_live)
      assert html =~ "Base deck updated successfully"
      assert html =~ "some updated name"
    end
  end
end
