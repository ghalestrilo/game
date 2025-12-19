defmodule GameWeb.CampaignLiveTest do
  use GameWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "Campaign" do
    test "navigating to /campaign renders character select page", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/campaign/character-select")

      assert html =~ "Select Your Character"
    end
  end
end
