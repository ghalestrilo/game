defmodule Game.BaseDecks.BaseDeck do
  use Ecto.Schema
  import Ecto.Changeset

  alias Game.BaseCards.BaseCard, as: Card
  alias Game.BaseCards.BaseCard, as: Card

  schema "decks" do
    field :name, :string
    has_many :cards, through: [:base_deck_cards, :card]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(base_deck, attrs) do
    base_deck
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
