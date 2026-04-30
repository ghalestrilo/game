defmodule Game.Repo.Migrations.AddRangeToCards do
  use Ecto.Migration

  def change do
    alter table(:cards) do
      add :range, :integer, null: true
    end
  end
end
