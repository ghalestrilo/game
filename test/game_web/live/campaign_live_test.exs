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

    test "complete combat sequence: hero defeats wolf and shop appears", %{
      conn: conn,
      hero_class: hero_class
    } do
      # Navigate to character select and start campaign
      {:ok, view, _html} = live(conn, ~p"/campaign/character-select")

      view
      |> form("form[phx-change='update_player_name']", %{player_name: "Test"})
      |> render_change()

      view
      |> element("div[phx-click='select_character'][phx-value-id='#{hero_class.id}']")
      |> render_click()

      view
      |> element("button[phx-click='start_campaign']")
      |> render_click()

      # Follow redirect to combat
      {:ok, play_view, _html} = live(conn, ~p"/campaign/play?class=hero&player_name=Test")
      render(play_view)

      # Turn 1: Hero attacks Wolf (Wolf HP: 2 -> 1)
      # Pick the attack card (index 0)
      play_view
      |> element("div[phx-click='pick_card'][phx-value-card_index='0']")
      |> render_click()

      # Play card on Wolf at position {2, -1, -1}
      play_view
      |> element("div[phx-click='interact'][phx-value-target_position='2_-1_-1']")
      |> render_click()

      # Skip turn to end Hero's turn
      play_view
      |> element("button[phx-click='skip_turn']")
      |> render_click()

      # Turn 2: Wolf's turn - skip to end Wolf's turn
      play_view
      |> element("button[phx-click='skip_turn']")
      |> render_click()

      # Turn 3: Hero attacks Wolf again (Wolf HP: 1 -> 0, game over)
      # Pick the attack card
      play_view
      |> element("div[phx-click='pick_card'][phx-value-card_index='0']")
      |> render_click()

      # Play card on Wolf
      play_view
      |> element("div[phx-click='interact'][phx-value-target_position='2_-1_-1']")
      |> render_click()

      # Render to get the updated state
      html = render(play_view)

      # Verify game over state
      assert html =~ "game_over"

      # Verify game over modal appears
      assert html =~ "Combat Complete!"

      # Verify shop button appears in the modal
      assert html =~ "Continue to Shop"
      assert html =~ "enter_shop"

      # Verify Hero survived and Wolf was defeated
      assert html =~ "Surviving Characters"
      assert html =~ "Hero"
      # Wolf should not be in the surviving characters list
      refute html =~ "Surviving Characters" && html =~ ">Wolf<"
    end
  end
end
