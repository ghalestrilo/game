defmodule Game.BaseCardsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Game.BaseCards` context.
  """

  @doc """
  Generate a base_card.
  """
  def base_card_fixture(attrs \\ %{}) do
    {:ok, base_card} =
      attrs
      |> Enum.into(%{
        ap: 42,
        effects: [],
        headline: "some headline",
        name: "some name",
        rarity: :common
      })
      |> Game.BaseCards.create_base_card()

    base_card
  end
end
