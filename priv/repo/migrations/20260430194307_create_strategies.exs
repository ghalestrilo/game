defmodule Game.Repo.Migrations.CreateStrategies do
  use Ecto.Migration

  def change do
    create table(:strategies) do
      add :name, :string, null: false
      add :gambits, {:array, :map}, null: false, default: []

      timestamps(type: :utc_datetime)
    end

    create unique_index(:strategies, [:name])
  end
end
