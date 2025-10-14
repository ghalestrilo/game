defmodule Game.Data.Character do
  use Ecto.Schema
  import Ecto.Changeset
  alias Game.BaseDecks.BaseDeck, as: Deck

  schema "characters" do
    field :class, :string
    field :base_hp, :integer
    field :base_ap, :integer
    field :base_movement, :integer
    # field :deck_id, :id
    belongs_to :deck, Deck

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(character, attrs) do
    character
    |> cast(attrs, [:class, :base_hp, :base_ap, :base_movement, :deck_id])
    |> validate_required([:class, :base_hp, :base_ap, :base_movement])
  end
end
