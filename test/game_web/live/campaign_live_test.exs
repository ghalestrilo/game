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

    # Create a fireball card for the shop
    {:ok, fireball_card} =
      BaseCards.create_base_card(%{
        name: "Fireball",
        ap: 2,
        effects: [%{"type" => "damage", "value" => 3}],
        headline: "Deal 3 damage",
        rarity: :rare
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

    %{
      hero_class: hero_class,
      wolf_class: wolf_class,
      attack_card: attack_card,
      fireball_card: fireball_card
    }
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

      # Follow the redirect to verify combat view loads
      {:ok, play_view, _html} = live(conn, ~p"/campaign/play?class=hero&player_name=Test")

      # Wait for the WebSocket connection and combat to initialize
      # by rendering the view which triggers the connected mount
      html = render(play_view)

      # Verify combat view is rendered with hero and wolf characters
      # Check for Combat State panel to ensure view loaded
      assert html =~ "Next up"

      # Check that both characters appear in the grid/queue
      # Character names appear in the Turn Queue and on the grid
      assert html =~ "Hero"
      assert html =~ "Wolf"

      # Verify both characters are in the turn queue (Hero is current, has badge)
      assert html =~ "badge-success"
      assert html =~ "Hero"
      assert html =~ "Wolf"
    end

    @tag :skip
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

      # Click "Continue to Shop" button
      play_view
      |> element("button[phx-click='enter_shop']")
      |> render_click()

      # Verify we're in the shop view
      html = render(play_view)
      assert html =~ "The Shop"

      # Select the Fireball card from the shop (index 2, as seen in shop output)
      play_view
      |> element("div[phx-click='select_shop_card'][phx-value-card_index='2']")
      |> render_click()

      # Verify we're back in combat with a fresh combat instance
      html = render(play_view)
      assert html =~ "Next up"

      # Verify characters are shown in the turn queue (full HP = all pip spans are bg-error)
      assert html =~ "bg-error"
      assert html =~ "bg-warning"

      # Verify the Fireball card is now in the player's hand
      # The player draws 5 cards at the start, and Fireball was added to their deck
      assert html =~ "Fireball"
    end

    @tag :skip
    test "druid summons wolf then defeats enemy wolf and shop appears", %{
      conn: conn,
      wolf_class: _wolf_class
    } do
      # Create a kill card that deals 999 damage
      {:ok, kill_card} =
        BaseCards.create_base_card(%{
          name: "Kill",
          ap: 1,
          effects: [%{"type" => "damage", "value" => 999}],
          headline: "Instant death",
          rarity: :legendary
        })

      # Create a summon wolf card
      {:ok, summon_wolf_card} =
        BaseCards.create_base_card(%{
          name: "Summon Wolf",
          ap: 1,
          effects: [%{"type" => "summon", "value" => "wolf"}],
          headline: "Summon a wolf ally",
          rarity: :rare
        })

      # Create deck for druid with only kill and summon cards
      {:ok, druid_deck} =
        BaseDecks.create_base_deck(%{
          "name" => "Druid Deck",
          "base_deck_cards" => [
            %{"card_id" => kill_card.id, "count" => 5},
            %{"card_id" => summon_wolf_card.id, "count" => 5}
          ]
        })

      # Create druid base class
      {:ok, druid_class} =
        Content.create_base_class(%{
          class: "druid",
          base_hp: 10,
          base_ap: 5,
          base_movement: 2,
          deck_id: druid_deck.id
        })

      # Navigate to character select and start campaign
      {:ok, view, _html} = live(conn, ~p"/campaign/character-select")

      view
      |> form("form[phx-change='update_player_name']", %{player_name: "DruidTest"})
      |> render_change()

      view
      |> element("div[phx-click='select_character'][phx-value-id='#{druid_class.id}']")
      |> render_click()

      view
      |> element("button[phx-click='start_campaign']")
      |> render_click()

      # Follow redirect to combat
      {:ok, play_view, _html} = live(conn, ~p"/campaign/play?class=druid&player_name=DruidTest")
      html = render(play_view)

      # Verify initial combat state: Druid vs Wolf
      assert html =~ "Druid"
      assert html =~ "Wolf"

      # Turn 1: Druid summons a wolf
      # Try each card until we successfully summon (some cards might be kill cards)
      summon_result =
        Enum.reduce_while(0..4, nil, fn idx, _acc ->
          # Check if the card at this index still exists (might have been played already)
          cards = play_view |> render() |> String.match?(~r/phx-value-card_index="#{idx}"/)

          if not cards do
            # Card was already played, we're done
            {:halt, :ok}
          else
            # Pick the card at this index
            play_view
            |> element("div[phx-click='pick_card'][phx-value-card_index='#{idx}']")
            |> render_click()

            # Try to play it on empty tile adjacent to druid
            result =
              play_view
              |> element("div[phx-click='interact'][phx-value-target_position='1_0_-1']")
              |> render_click()

            # Check if it succeeded (no error flash)
            if result =~ "Tile must be empty" or result =~ "No character at this position" do
              {:cont, nil}
            else
              {:halt, :ok}
            end
          end
        end)

      assert summon_result == :ok, "None of the 5 cards could be played as summon"

      html = render(play_view)

      # Verify a wolf was summoned - should now have 2 wolves total (1 enemy + 1 summoned)
      # The summoned wolf should appear in the queue or on the grid
      wolf_count = html |> String.split("Wolf") |> length() |> Kernel.-(1)

      assert wolf_count >= 2,
             "Expected at least 2 wolves (1 enemy + 1 summoned), found #{wolf_count}"

      # Skip turn to end Druid's turn
      play_view
      |> element("button[phx-click='skip_turn']")
      |> render_click()

      # Turn 2: Enemy Wolf's turn - skip
      play_view
      |> element("button[phx-click='skip_turn']")
      |> render_click()

      # Turn 3: Summoned Wolf's turn - skip
      play_view
      |> element("button[phx-click='skip_turn']")
      |> render_click()

      # Turn 4: Druid kills the enemy wolf
      # Try each card until we successfully attack (avoid summon cards)
      kill_result =
        Enum.reduce_while(0..4, nil, fn idx, _acc ->
          # First check if game is already over
          current_html = render(play_view)

          if current_html =~ "game_over" do
            # Game is over, we succeeded
            {:halt, :ok}
          else
            # Check if the card at this index still exists
            cards = current_html =~ ~r/phx-value-card_index="#{idx}"/

            if not cards do
              # No more cards at this index
              {:cont, nil}
            else
              # Pick the card at this index
              play_view
              |> element("div[phx-click='pick_card'][phx-value-card_index='#{idx}']")
              |> render_click()

              # Try to play it on enemy wolf at {2, -1, -1}
              result =
                play_view
                |> element("div[phx-click='interact'][phx-value-target_position='2_-1_-1']")
                |> render_click()

              # Check if game is over after playing
              cond do
                result =~ "game_over" ->
                  {:halt, :ok}

                result =~ "Tile must be empty" or result =~ "No character at this position" ->
                  {:cont, nil}

                true ->
                  # Succeeded but game not over yet
                  {:halt, :ok}
              end
            end
          end
        end)

      assert kill_result == :ok, "Could not find kill card to attack enemy wolf"

      # Render to get the updated state
      html = render(play_view)

      # Verify game over state
      assert html =~ "game_over"

      # Verify game over modal appears
      assert html =~ "Combat Complete!"

      # Verify shop button appears
      assert html =~ "Continue to Shop"
      assert html =~ "enter_shop"

      # Verify Druid and summoned wolf survived
      assert html =~ "Surviving Characters"
      assert html =~ "Druid"

      # Enemy wolf should not be in surviving characters
      # This is tricky because we have multiple wolves, but the enemy wolf should be dead
      # The summoned wolf should still be alive
      # We can verify by checking that we have exactly 2 surviving characters (Druid + summoned wolf)
      surviving_section = String.split(html, "Surviving Characters") |> Enum.at(1, "")
      druid_count = surviving_section |> String.split("Druid") |> length() |> Kernel.-(1)
      wolf_count_surviving = surviving_section |> String.split("Wolf") |> length() |> Kernel.-(1)

      assert druid_count == 1, "Expected 1 Druid in surviving characters"
      assert wolf_count_surviving == 1, "Expected 1 Wolf (summoned) in surviving characters"
    end
  end
end
