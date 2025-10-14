defmodule Game.BaseDecks.BaseDeck do
  use Ecto.Schema
  import Ecto.Changeset

  schema "decks" do
    field :name, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(base_deck, attrs) do
    base_deck
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
