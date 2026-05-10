defmodule Game.BaseDecksTest do
  use Game.DataCase

  alias Game.BaseDecks
  alias Game.Content
  alias Game.Content.BaseDeckCard

  describe "basedecks" do
    alias Game.BaseDecks.BaseDeck

    import Game.BaseDecksFixtures

    @invalid_attrs %{name: nil}

    test "list_basedecks/0 returns all basedecks" do
      base_deck = base_deck_fixture()
      listed = BaseDecks.list_basedecks() |> Game.Repo.preload([:base_deck_cards, :cards])
      assert listed == [base_deck]
    end

    test "get_base_deck!/1 returns the base_deck with given id" do
      base_deck = base_deck_fixture()
      assert BaseDecks.get_base_deck!(base_deck.id) == base_deck
    end

    test "create_base_deck/1 with valid data creates a base_deck" do
      valid_attrs = %{name: "some name"}

      assert {:ok, %BaseDeck{} = base_deck} = BaseDecks.create_base_deck(valid_attrs)
      assert base_deck.name == "some name"
    end

    test "create_base_deck/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = BaseDecks.create_base_deck(@invalid_attrs)
    end

    test "update_base_deck/2 with valid data updates the base_deck" do
      base_deck = base_deck_fixture()
      update_attrs = %{name: "some updated name"}

      assert {:ok, %BaseDeck{} = base_deck} = BaseDecks.update_base_deck(base_deck, update_attrs)
      assert base_deck.name == "some updated name"
    end

    test "update_base_deck/2 with invalid data returns error changeset" do
      base_deck = base_deck_fixture()
      assert {:error, %Ecto.Changeset{}} = BaseDecks.update_base_deck(base_deck, @invalid_attrs)
      assert base_deck == BaseDecks.get_base_deck!(base_deck.id)
    end

    test "delete_base_deck/1 deletes the base_deck" do
      base_deck = base_deck_fixture()
      assert {:ok, %BaseDeck{}} = BaseDecks.delete_base_deck(base_deck)
      assert_raise Ecto.NoResultsError, fn -> BaseDecks.get_base_deck!(base_deck.id) end
    end

    test "change_base_deck/1 returns a base_deck changeset" do
      base_deck = base_deck_fixture()
      assert %Ecto.Changeset{} = BaseDecks.change_base_deck(base_deck)
    end
  end

  describe "get_base_deck_cards/1" do
    import Game.BaseDecksFixtures
    import Game.BaseCardsFixtures

    test "returns expanded Game.Card list respecting count" do
      deck = base_deck_fixture()
      card = base_card_fixture(%{name: "Fireball", ap: 2})

      Game.Repo.insert!(%BaseDeckCard{deck_id: deck.id, card_id: card.id, count: 3})

      cards = Content.get_base_deck_cards(deck)

      assert length(cards) == 3
      assert Enum.all?(cards, fn c -> c.name == "Fireball" and c.cost == 2 end)
      assert Enum.all?(cards, &is_struct(&1, Game.Card))
    end

    test "returns cards for multiple distinct entries" do
      deck = base_deck_fixture()
      card_a = base_card_fixture(%{name: "Slash"})
      card_b = base_card_fixture(%{name: "Shield Bash"})

      Game.Repo.insert!(%BaseDeckCard{deck_id: deck.id, card_id: card_a.id, count: 2})
      Game.Repo.insert!(%BaseDeckCard{deck_id: deck.id, card_id: card_b.id, count: 1})

      cards = Content.get_base_deck_cards(deck)

      assert length(cards) == 3
      assert Enum.count(cards, &(&1.name == "Slash")) == 2
      assert Enum.count(cards, &(&1.name == "Shield Bash")) == 1
    end

    test "accepts a deck id" do
      deck = base_deck_fixture()
      card = base_card_fixture()
      Game.Repo.insert!(%BaseDeckCard{deck_id: deck.id, card_id: card.id, count: 1})

      cards = Content.get_base_deck_cards(deck.id)

      assert length(cards) == 1
    end

    test "returns empty list for deck with no cards" do
      deck = base_deck_fixture()
      assert Content.get_base_deck_cards(deck) == []
    end
  end
end
