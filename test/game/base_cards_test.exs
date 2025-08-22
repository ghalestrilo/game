defmodule Game.BaseCardsTest do
  use Game.DataCase

  alias Game.BaseCards

  describe "basecards" do
    alias Game.BaseCards.BaseCard

    import Game.BaseCardsFixtures

    @invalid_attrs %{name: nil, effects: nil, ap: nil, headline: nil, rarity: nil}

    test "list_basecards/0 returns all basecards" do
      base_card = base_card_fixture()
      assert BaseCards.list_basecards() == [base_card]
    end

    test "get_base_card!/1 returns the base_card with given id" do
      base_card = base_card_fixture()
      assert BaseCards.get_base_card!(base_card.id) == base_card
    end

    test "create_base_card/1 with valid data creates a base_card" do
      valid_attrs = %{name: "some name", effects: [], ap: 42, headline: "some headline", rarity: :common}

      assert {:ok, %BaseCard{} = base_card} = BaseCards.create_base_card(valid_attrs)
      assert base_card.name == "some name"
      assert base_card.effects == []
      assert base_card.ap == 42
      assert base_card.headline == "some headline"
      assert base_card.rarity == :common
    end

    test "create_base_card/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = BaseCards.create_base_card(@invalid_attrs)
    end

    test "update_base_card/2 with valid data updates the base_card" do
      base_card = base_card_fixture()
      update_attrs = %{name: "some updated name", effects: [], ap: 43, headline: "some updated headline", rarity: :uncommon}

      assert {:ok, %BaseCard{} = base_card} = BaseCards.update_base_card(base_card, update_attrs)
      assert base_card.name == "some updated name"
      assert base_card.effects == []
      assert base_card.ap == 43
      assert base_card.headline == "some updated headline"
      assert base_card.rarity == :uncommon
    end

    test "update_base_card/2 with invalid data returns error changeset" do
      base_card = base_card_fixture()
      assert {:error, %Ecto.Changeset{}} = BaseCards.update_base_card(base_card, @invalid_attrs)
      assert base_card == BaseCards.get_base_card!(base_card.id)
    end

    test "delete_base_card/1 deletes the base_card" do
      base_card = base_card_fixture()
      assert {:ok, %BaseCard{}} = BaseCards.delete_base_card(base_card)
      assert_raise Ecto.NoResultsError, fn -> BaseCards.get_base_card!(base_card.id) end
    end

    test "change_base_card/1 returns a base_card changeset" do
      base_card = base_card_fixture()
      assert %Ecto.Changeset{} = BaseCards.change_base_card(base_card)
    end
  end
end
