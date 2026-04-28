defmodule GameWeb.Admin.Filters.DeckFilter do
  use Backpex.Filters.Select

  import Ecto.Query

  @impl Backpex.Filter
  def label, do: "Deck"

  @impl Backpex.Filters.Select
  def prompt, do: "All decks"

  @impl Backpex.Filters.Select
  def options(_assigns) do
    Game.Repo.all(Game.BaseDecks.BaseDeck)
    |> Enum.map(&{&1.name, to_string(&1.id)})
  end

  @impl Backpex.Filter
  def query(query, _attribute, value, _assigns) do
    deck_id = String.to_integer(value)

    query
    |> join(:inner, [card], bdc in Game.Content.BaseDeckCard,
      on: bdc.card_id == card.id and bdc.deck_id == ^deck_id
    )
  end
end
