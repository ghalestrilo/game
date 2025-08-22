defmodule Game.BaseDecksTest do
  use Game.DataCase

  alias Game.BaseDecks

  describe "basedecks" do
    alias Game.BaseDecks.BaseDeck

    import Game.BaseDecksFixtures

    @invalid_attrs %{name: nil}

    test "list_basedecks/0 returns all basedecks" do
      base_deck = base_deck_fixture()
      assert BaseDecks.list_basedecks() == [base_deck]
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
end
