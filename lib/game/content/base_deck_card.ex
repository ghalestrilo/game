defmodule Game.Content.BaseDeckCard do
  use Ecto.Schema
  import Ecto.Changeset

  schema "basedeckcards" do
    field :count, :integer
    field :deck_id, :id
    field :card_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(base_deck_card, attrs) do
    base_deck_card
    |> cast(attrs, [:count])
    |> validate_required([:count])
  end
end
