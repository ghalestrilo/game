defmodule Game.Repo.Migrations.CreateMaps do
  use Ecto.Migration

  def change do
    create table(:maps) do
      add :slug, :string, null: false
      add :display_name, :string, null: false
      add :tiles, {:array, :map}, default: []
      add :spawn_points, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:maps, [:slug])
  end
end
