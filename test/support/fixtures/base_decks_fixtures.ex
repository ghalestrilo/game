defmodule Game.BaseDecksFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Game.BaseDecks` context.
  """

  @doc """
  Generate a base_deck.
  """
  def base_deck_fixture(attrs \\ %{}) do
    {:ok, base_deck} =
      attrs
      |> Enum.into(%{
        name: "some name"
      })
      |> Game.BaseDecks.create_base_deck()

    # Preload associations to match what get_base_deck! returns
    base_deck
    |> Game.Repo.preload([:base_deck_cards, :cards])
  end
end
