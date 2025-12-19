defmodule GameWeb.CampaignLiveTest do
  use GameWeb.ConnCase

  import Phoenix.LiveViewTest
  alias Game.{BaseCards, BaseDecks, Content}

  setup do
    # Create an attack card with 1 damage
    {:ok, attack_card} =
      BaseCards.create_base_card(%{
        name: "Attack",
        ap: 1,
        effects: [%{"type" => "damage", "value" => 1}],
        headline: "Deal 1 damage",
        rarity: :common
      })

    # Create deck for hero
    {:ok, hero_deck} =
      BaseDecks.create_base_deck(%{
        "name" => "Hero Deck",
        "base_deck_cards" => [
          %{"card_id" => attack_card.id, "count" => 1}
        ]
      })

    # Create deck for wolf (using wolf instead of beast due to hardcoded enemy type)
    {:ok, wolf_deck} =
      BaseDecks.create_base_deck(%{
        "name" => "Wolf Deck",
        "base_deck_cards" => [
          %{"card_id" => attack_card.id, "count" => 1}
        ]
      })

    # Create hero base class
    {:ok, hero_class} =
      Content.create_base_class(%{
        class: "hero",
        base_hp: 2,
        base_ap: 3,
        base_movement: 3,
        deck_id: hero_deck.id
      })

    # Create wolf base class (hardcoded enemy in campaign_play_live.ex)
    {:ok, wolf_class} =
      Content.create_base_class(%{
        class: "wolf",
        base_hp: 2,
        base_ap: 3,
        base_movement: 3,
        deck_id: wolf_deck.id
      })

    %{hero_class: hero_class, wolf_class: wolf_class, attack_card: attack_card}
  end

  describe "Campaign" do
    test "navigating to /campaign renders character select page", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/campaign/character-select")

      assert html =~ "Select Your Character"
    end

    test "selecting hero and starting campaign shows combat view with hero and wolf", %{
      conn: conn,
      hero_class: hero_class
    } do
      # Navigate to character select
      {:ok, view, _html} = live(conn, ~p"/campaign/character-select")

      # Enter player name
      view
      |> form("form[phx-change='update_player_name']", %{player_name: "Test"})
      |> render_change()

      # Select hero character
      view
      |> element("div[phx-click='select_character'][phx-value-id='#{hero_class.id}']")
      |> render_click()

      # Start campaign
      view
      |> element("button[phx-click='start_campaign']")
      |> render_click()

      # Should navigate to campaign play
      assert_redirect(view, ~p"/campaign/play?class=hero&player_name=Test")

      # Follow the redirect to verify combat view loads
      {:ok, play_view, _html} = live(conn, ~p"/campaign/play?class=hero&player_name=Test")

      # Wait for the WebSocket connection and combat to initialize
      # by rendering the view which triggers the connected mount
      html = render(play_view)

      # Verify combat view is rendered with hero and wolf characters
      # Check for Combat State panel to ensure view loaded
      assert html =~ "Combat State"

      # Check that both characters appear in the grid/queue
      # Character names appear in the Turn Queue and on the grid
      assert html =~ "Hero"
      assert html =~ "Wolf"

      # Verify both characters are in the turn queue
      assert html =~ "Character&lt;Hero"
      assert html =~ "Character&lt;Wolf"
    end
  end
end
