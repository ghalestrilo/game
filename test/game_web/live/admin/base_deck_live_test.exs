defmodule GameWeb.Admin.BaseDeckLiveTest do
  use GameWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Game.{BaseCards, BaseDecks}

  setup :register_and_log_in_admin

  setup do
    {:ok, card_a} =
      BaseCards.create_base_card(%{
        name: "Strike-#{System.unique_integer([:positive])}",
        ap: 1,
        effects: [],
        headline: "Deal damage",
        rarity: :common
      })

    {:ok, card_b} =
      BaseCards.create_base_card(%{
        name: "Fireball-#{System.unique_integer([:positive])}",
        ap: 2,
        effects: [],
        headline: "AoE damage",
        rarity: :rare
      })

    {:ok, deck} =
      BaseDecks.create_base_deck(%{
        "name" => "Test Deck",
        "base_deck_cards" => [%{"card_id" => card_a.id, "count" => 2}]
      })

    %{deck: deck, card_a: card_a, card_b: card_b}
  end

  defp save_deck(view, change_params) do
    view
    |> form("#resource-form", %{"change" => change_params})
    |> render_submit(%{"save-type" => "save"})
  end

  test "can save deck without changing cards", %{conn: conn, deck: deck} do
    {:ok, view, _html} = live(conn, ~p"/admin/base_decks/#{deck.id}/edit")

    save_deck(view, %{"name" => deck.name})

    assert Game.BaseDecks.get_base_deck!(deck.id).name == deck.name
  end

  test "can change card count and save", %{conn: conn, deck: deck} do
    {:ok, view, _html} = live(conn, ~p"/admin/base_decks/#{deck.id}/edit")
    [card_entry] = deck.base_deck_cards

    save_deck(view, %{
      "name" => deck.name,
      "base_deck_cards" => %{
        "0" => %{
          "id" => to_string(card_entry.id),
          "card_id" => to_string(card_entry.card_id),
          "count" => "5"
        }
      },
      "base_deck_cards_order" => ["0"]
    })

    updated = Game.BaseDecks.get_base_deck!(deck.id)
    assert hd(updated.base_deck_cards).count == 5
  end

  test "can add a new card and save", %{deck: deck, card_a: card_a, card_b: card_b} do
    [card_entry] = deck.base_deck_cards

    # Simulate what Backpex sends: nested card params without deck_id
    {:ok, updated} =
      BaseDecks.update_base_deck(deck, %{
        "name" => deck.name,
        "base_deck_cards" => %{
          "0" => %{
            "id" => to_string(card_entry.id),
            "card_id" => to_string(card_a.id),
            "count" => "2"
          },
          "1" => %{"card_id" => to_string(card_b.id), "count" => "3"}
        },
        "base_deck_cards_order" => ["0", "1"]
      })

    updated = Game.Repo.preload(updated, :base_deck_cards)
    assert length(updated.base_deck_cards) == 2
  end
end
