defmodule Game.Repo.Migrations.CreateFormulaAliases do
  use Ecto.Migration

  def change do
    create table(:formula_aliases) do
      add :name, :string, null: false
      add :expression, :map, null: false
      add :description, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:formula_aliases, [:name])
  end
end
