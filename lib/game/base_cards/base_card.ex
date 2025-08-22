defmodule Game.BaseCards.BaseCard do
  use Ecto.Schema
  import Ecto.Changeset

  schema "basecards" do
    field :name, :string
    field :effects, {:array, :map}
    field :ap, :integer
    field :headline, :string
    field :rarity, Ecto.Enum, values: [:common, :uncommon, :rare, :legendary]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(base_card, attrs) do
    base_card
    |> cast(attrs, [:name, :effects, :ap, :headline, :rarity])
    |> validate_required([:name, :effects, :ap, :headline, :rarity])
  end
end
