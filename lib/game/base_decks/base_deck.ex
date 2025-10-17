defmodule Game.BaseDecks.BaseDeck do
  use Ecto.Schema
  import Ecto.Changeset

  alias Game.Content.BaseDeckCard, as: BaseDeckCard

  schema "decks" do
    field :name, :string
    has_many :base_deck_cards, BaseDeckCard, foreign_key: :deck_id, on_replace: :delete
    has_many :cards, through: [:base_deck_cards, :card]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(base_deck, attrs) do
    base_deck
    |> cast(attrs, [:name])
    |> cast_assoc(:base_deck_cards, with: &Game.Content.BaseDeckCard.changeset/2)
    |> validate_required([:name])
  end
end
