defmodule Game.Repo.Migrations.CreateBaseCards do
  use Ecto.Migration

  def change do
    create table(:cards) do
      add :name, :string
      add :effects, {:array, :map}
      add :ap, :integer
      add :headline, :string
      add :rarity, :string

      timestamps(type: :utc_datetime)
    end
  end
end
