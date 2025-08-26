defmodule GameWeb.GameLiveTest do
  use GameWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "Bug reproduction - empty hands after turn transitions" do
    test "skipping turn doesn't draw cards for next player", %{conn: conn} do
      # Load the game page
      {:ok, view, _html} = live(conn, ~p"/game")

      # Verify initial state has warrior as current player with 5 cards
      assert view |> element(".card-status-panel") |> render() =~ "Warrior"
      assert view |> element(".card-status-panel") |> render() =~ "Hand: 5 cards"

      # Skip the warrior's turn
      view
      |> element("button", "Skip Turn")
      |> render_click()

      # Verify now mage is the current player
      assert view |> element(".card-status-panel") |> render() =~ "Mage"

      # This reproduces the bug - Mage should have 5 cards but has 0
      hand_content = view |> element(".card-status-panel") |> render()
      assert hand_content =~ "Hand: 5 cards"
      refute hand_content =~ "Hand: 0 cards"

      # Skip again to go back to warrior
      view
      |> element("button", "Skip Turn")
      |> render_click()

      # Verify warrior is now current player
      assert view |> element(".card-status-panel") |> render() =~ "Warrior"

      # Warrior should also have an empty hand now due to the bug
      hand_content = view |> element(".card-status-panel") |> render()
      assert hand_content =~ "Hand: 5 cards"
      refute hand_content =~ "Hand: 0 cards"
    end
  end
end
