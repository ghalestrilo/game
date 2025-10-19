defmodule Game.Content.BaseDeckCard do
  use Ecto.Schema
  import Ecto.Changeset
  alias Game.BaseDecks.BaseDeck, as: Deck
  alias Game.BaseCards.BaseCard, as: Card

  schema "base_deck_cards" do
    field :count, :integer
    belongs_to :deck, Deck, foreign_key: :deck_id
    belongs_to :card, Card, foreign_key: :card_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(base_deck_card, attrs) do
    base_deck_card
    |> cast(attrs, [:card_id, :deck_id, :count])
    |> validate_required([:card_id, :deck_id, :count])
  end
end
