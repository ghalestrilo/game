defmodule GameWeb.BaseCardLiveTest do
  use GameWeb.ConnCase

  import Phoenix.LiveViewTest
  import Game.BaseCardsFixtures

  @create_attrs %{
    name: "some name",
    effects: [],
    ap: 5,
    headline: "some headline",
    rarity: :common
  }
  @update_attrs %{
    name: "some updated name",
    effects: [],
    ap: 10,
    headline: "some updated headline",
    rarity: :uncommon
  }
  @invalid_attrs %{name: nil, effects: [], ap: nil, headline: nil, rarity: nil}

  defp create_base_card(_) do
    base_card = base_card_fixture()
    %{base_card: base_card}
  end

  describe "Index" do
    setup [:create_base_card]

    test "lists all basecards", %{conn: conn, base_card: base_card} do
      {:ok, _index_live, html} = live(conn, ~p"/admin/basecards")

      assert html =~ "Listing Basecards"
      assert html =~ base_card.name
    end

    test "saves new base_card", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/basecards")

      assert index_live |> element("a", "New Base card") |> render_click() =~
               "New Base card"

      assert_patch(index_live, ~p"/admin/basecards/new")

      assert index_live
             |> form("#base_card-form", base_card: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      result =
        index_live
        |> form("#base_card-form", base_card: @create_attrs)
        |> render_submit()

      # Print form content to check for errors
      if result =~ "base_card-form" do
        IO.puts("\n=== FORM STILL PRESENT, likely validation error ===")
        # Look for phx-feedback-for attributes which indicate field errors
        if result =~ "phx-feedback-for" do
          IO.puts("Found field validation errors")
        end
      end

      assert_patch(index_live, ~p"/admin/basecards")

      html = render(index_live)
      assert html =~ "Base card created successfully"
      assert html =~ "some name"
    end

    test "updates base_card in listing", %{conn: conn, base_card: base_card} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/basecards")

      assert index_live |> element("#basecards-#{base_card.id} a", "Edit") |> render_click() =~
               "Edit Base card"

      assert_patch(index_live, ~p"/admin/basecards/#{base_card}/edit")

      assert index_live
             |> form("#base_card-form", base_card: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#base_card-form", base_card: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/admin/basecards")

      html = render(index_live)
      assert html =~ "Base card updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes base_card in listing", %{conn: conn, base_card: base_card} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/basecards")

      assert index_live |> element("#basecards-#{base_card.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#basecards-#{base_card.id}")
    end
  end

  describe "Show" do
    setup [:create_base_card]

    test "displays base_card", %{conn: conn, base_card: base_card} do
      {:ok, _show_live, html} = live(conn, ~p"/admin/basecards/#{base_card}")

      assert html =~ "Show Base card"
      assert html =~ base_card.name
    end

    test "updates base_card within modal", %{conn: conn, base_card: base_card} do
      {:ok, show_live, _html} = live(conn, ~p"/admin/basecards/#{base_card}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Base card"

      assert_patch(show_live, ~p"/admin/basecards/#{base_card}/show/edit")

      assert show_live
             |> form("#base_card-form", base_card: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#base_card-form", base_card: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/admin/basecards/#{base_card}")

      html = render(show_live)
      assert html =~ "Base card updated successfully"
      assert html =~ "some updated name"
    end
  end
end
