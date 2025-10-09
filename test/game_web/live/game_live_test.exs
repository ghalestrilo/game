defmodule GameWeb.GameLiveTest do
  use GameWeb.ConnCase

  import Phoenix.LiveViewTest


  describe "Game state initialization from query parameter" do
    test "Loads game state from `initial_state` query parameter", %{conn: conn} do
      # Define the initial state as a list of tuples
      initial_state = [
        {{0, 0, 0}, :warrior, 1},
        {{0, 1, 1}, :mage, 2}
      ]

      # Serialize the initial state into a URI-safe string
      serialized_state =
        initial_state
        |> :erlang.term_to_binary()
        |> Base.url_encode64(padding: false)

      # Construct the URI with the `initial_state` query parameter
      uri = ~p"/game?initial_state=#{serialized_state}"

      # Load the game page with the query parameter
      {:ok, view, _html} = live(conn, uri)

      # Verify that the game state is initialized correctly
      assert view |> element("[phx-value-target_position=\"0_0_0\"]") |> has_element?()
      assert view |> element("[phx-value-target_position=\"0_1_1\"]") |> has_element?()

      # Verify that the characters are positioned correctly
      assert view |> render() =~ "Warrior"
      assert view |> render() =~ "Mage"
    end
  end
  describe "Combat sandbox demo" do

  test "Drawing a card changes turn to next character with a freshly drawn 5-card hand", %{conn: conn} do
      # Load the game page
      {:ok, view, _html} = live(conn, ~p"/game")

      # Verify initial state has warrior as current player with 5 cards
      assert view |> element(".card-status-panel") |> render() =~ "Warrior"
      assert view |> element(".card-status-panel") |> render() =~ "Hand: 5 cards"

      # Have the warrior attack himself
      assert view |> render() =~ "HP: 20"
      pick_first_card(view)
      click_warrior(view)
      assert view |> render() =~ "HP: 15" # (new hp)

      # Verify now mage is the current player
      assert view |> element(".card-status-panel") |> render() =~ "Mage"

      # Ensure mage has 5 cards in his hand
      hand_content = view |> element(".card-status-panel") |> render()
      assert hand_content =~ "Hand: 5 cards"
      refute hand_content =~ "Hand: 0 cards"

      # Have mage attack himself
      pick_first_card(view)
      click_warrior(view)

      # Verify warrior is now current player
      assert view |> element(".card-status-panel") |> render() =~ "Warrior"

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

  defp click_mage(view) do
    view
    |> element("[phx-value-target_position=\"0_-1_-1\"]")
    |> render_click()
  end
end
