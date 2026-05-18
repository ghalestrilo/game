defmodule GameWeb.CardModalTest do
  use GameWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component

  defp make_card(name) do
    %Game.Card{
      id: :erlang.phash2(name),
      base_card_id: 1,
      name: name,
      headline: "Test",
      cost: 1,
      effects: [],
      range: 0,
      rarity: :common,
      targeting: %{"type" => "character"}
    }
  end

  defp render_card_modal(opts) do
    cards = Keyword.fetch!(opts, :cards)
    ordered = Keyword.get(opts, :ordered, false)

    assigns = %{cards: cards, ordered: ordered}

    rendered =
      rendered_to_string(~H"""
      <GameWeb.CoreComponents.card_modal
        id="test-modal"
        show={true}
        cards={@cards}
        ordered={@ordered}
      />
      """)

    rendered
  end

  describe "card_modal ordered: true" do
    test "renders cards in the order provided" do
      cards = Enum.map(["Alpha", "Beta", "Gamma", "Delta"], &make_card/1)
      html = render_card_modal(cards: cards, ordered: true)

      positions =
        Enum.map(cards, fn card ->
          {card.name, :binary.match(html, card.name) |> elem(0)}
        end)

      sorted = Enum.sort_by(positions, &elem(&1, 1))
      assert Enum.map(sorted, &elem(&1, 0)) == Enum.map(cards, & &1.name)
    end
  end

  describe "card_modal ordered: false (default)" do
    test "renders all cards regardless of order" do
      cards = Enum.map(["Alpha", "Beta", "Gamma", "Delta"], &make_card/1)
      html = render_card_modal(cards: cards, ordered: false)

      for card <- cards do
        assert html =~ card.name
      end
    end

    test "display order may differ from input order across multiple renders" do
      cards = Enum.map(1..20, fn i -> make_card("Card#{i}") end)

      orders =
        for _ <- 1..20 do
          html = render_card_modal(cards: cards, ordered: false)

          Enum.map(cards, fn card ->
            {card.name, :binary.match(html, card.name) |> elem(0)}
          end)
          |> Enum.sort_by(&elem(&1, 1))
          |> Enum.map(&elem(&1, 0))
        end

      # With 20 cards, at least two renders should differ (probability of collision ≈ 0)
      assert Enum.uniq(orders) |> length() > 1
    end
  end
end
