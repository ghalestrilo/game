defmodule Game.FormulaAliases.FormulaAlias do
  use Ecto.Schema
  import Ecto.Changeset

  schema "formula_aliases" do
    field :name, :string
    field :expression, :map
    field :description, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(alias, attrs) do
    alias
    |> cast(attrs, [:name, :expression, :description])
    |> validate_required([:name, :expression])
    |> validate_format(:name, ~r/^\w+$/,
      message: "must contain only letters, digits, and underscores"
    )
    |> unique_constraint(:name)
  end
end
