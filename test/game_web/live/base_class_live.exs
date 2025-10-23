defmodule GameWeb.BaseClassLiveTest do
  use GameWeb.ConnCase

  import Phoenix.LiveViewTest
  import Game.DataFixtures

  @create_attrs %{class: "some class", base_hp: 42, base_ap: 42, base_movement: 42}
  @update_attrs %{class: "some updated class", base_hp: 43, base_ap: 43, base_movement: 43}
  @invalid_attrs %{class: nil, base_hp: nil, base_ap: nil, base_movement: nil}

  defp create_base_class(_) do
    base_class = base_class_fixture()
    %{base_class: base_class}
  end

  describe "Index" do
    setup [:create_base_class]

    test "lists all base_classes", %{conn: conn, base_class: base_class} do
      {:ok, _index_live, html} = live(conn, ~p"/base_classes")

      assert html =~ "Listing Characters"
      assert html =~ base_class.class
    end

    test "saves new base_class", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/base_classes")

      assert index_live |> element("a", "New Character") |> render_click() =~
               "New Character"

      assert_patch(index_live, ~p"/admin/base_classes/new")

      assert index_live
             |> form("#base_class-form", base_class: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#base_class-form", base_class: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/base_classes")

      html = render(index_live)
      assert html =~ "Character created successfully"
      assert html =~ "some class"
    end

    test "updates base_class in listing", %{conn: conn, base_class: base_class} do
      {:ok, index_live, _html} = live(conn, ~p"/base_classes")

      assert index_live |> element("#base_classes-#{base_class.id} a", "Edit") |> render_click() =~
               "Edit Character"

      assert_patch(index_live, ~p"/base_classes/#{base_class}/edit")

      assert index_live
             |> form("#base_class-form", base_class: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#base_class-form", base_class: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/base_classes")

      html = render(index_live)
      assert html =~ "Character updated successfully"
      assert html =~ "some updated class"
    end

    test "deletes base_class in listing", %{conn: conn, base_class: base_class} do
      {:ok, index_live, _html} = live(conn, ~p"/base_classes")

      assert index_live |> element("#base_classes-#{base_class.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#base_classes-#{base_class.id}")
    end
  end

  describe "Show" do
    setup [:create_base_class]

    test "displays base_class", %{conn: conn, base_class: base_class} do
      {:ok, _show_live, html} = live(conn, ~p"/base_classes/#{base_class}")

      assert html =~ "Show Character"
      assert html =~ base_class.class
    end

    test "updates base_class within modal", %{conn: conn, base_class: base_class} do
      {:ok, show_live, _html} = live(conn, ~p"/base_classes/#{base_class}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Character"

      assert_patch(show_live, ~p"/base_classes/#{base_class}/show/edit")

      assert show_live
             |> form("#base_class-form", base_class: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#base_class-form", base_class: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/base_classes/#{base_class}")

      html = render(show_live)
      assert html =~ "Character updated successfully"
      assert html =~ "some updated class"
    end
  end
end
