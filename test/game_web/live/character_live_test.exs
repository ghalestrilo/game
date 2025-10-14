defmodule GameWeb.CharacterLiveTest do
  use GameWeb.ConnCase

  import Phoenix.LiveViewTest
  import Game.DataFixtures

  @create_attrs %{class: "some class", base_hp: 42, base_ap: 42, base_movement: 42}
  @update_attrs %{class: "some updated class", base_hp: 43, base_ap: 43, base_movement: 43}
  @invalid_attrs %{class: nil, base_hp: nil, base_ap: nil, base_movement: nil}

  defp create_character(_) do
    character = character_fixture()
    %{character: character}
  end

  describe "Index" do
    setup [:create_character]

    test "lists all characters", %{conn: conn, character: character} do
      {:ok, _index_live, html} = live(conn, ~p"/characters")

      assert html =~ "Listing Characters"
      assert html =~ character.class
    end

    test "saves new character", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/characters")

      assert index_live |> element("a", "New Character") |> render_click() =~
               "New Character"

      assert_patch(index_live, ~p"/admin/characters/new")

      assert index_live
             |> form("#character-form", character: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#character-form", character: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/characters")

      html = render(index_live)
      assert html =~ "Character created successfully"
      assert html =~ "some class"
    end

    test "updates character in listing", %{conn: conn, character: character} do
      {:ok, index_live, _html} = live(conn, ~p"/characters")

      assert index_live |> element("#characters-#{character.id} a", "Edit") |> render_click() =~
               "Edit Character"

      assert_patch(index_live, ~p"/characters/#{character}/edit")

      assert index_live
             |> form("#character-form", character: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#character-form", character: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/characters")

      html = render(index_live)
      assert html =~ "Character updated successfully"
      assert html =~ "some updated class"
    end

    test "deletes character in listing", %{conn: conn, character: character} do
      {:ok, index_live, _html} = live(conn, ~p"/characters")

      assert index_live |> element("#characters-#{character.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#characters-#{character.id}")
    end
  end

  describe "Show" do
    setup [:create_character]

    test "displays character", %{conn: conn, character: character} do
      {:ok, _show_live, html} = live(conn, ~p"/characters/#{character}")

      assert html =~ "Show Character"
      assert html =~ character.class
    end

    test "updates character within modal", %{conn: conn, character: character} do
      {:ok, show_live, _html} = live(conn, ~p"/characters/#{character}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Character"

      assert_patch(show_live, ~p"/characters/#{character}/show/edit")

      assert show_live
             |> form("#character-form", character: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#character-form", character: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/characters/#{character}")

      html = render(show_live)
      assert html =~ "Character updated successfully"
      assert html =~ "some updated class"
    end
  end
end
