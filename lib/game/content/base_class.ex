defmodule Game.Content.BaseClass do
  use Ecto.Schema
  import Ecto.Changeset
  alias Game.BaseDecks.BaseDeck, as: Deck

  schema "base_classes" do
    field :class, :string
    field :avatar_url, :string
    field :base_hp, :integer
    field :base_ap, :integer
    field :base_movement, :integer
    belongs_to :deck, Deck

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(base_class, attrs) do
    base_class
    |> cast(attrs, [:class, :avatar_url, :base_hp, :base_ap, :base_movement, :deck_id])
    |> validate_required([:class, :base_hp, :base_ap, :base_movement])
  end
end
