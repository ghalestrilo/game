defmodule Game.Repo.Migrations.CreateBasedecks do
  use Ecto.Migration

  def change do
    create table(:basedecks) do
      add :name, :string

      timestamps(type: :utc_datetime)
    end
  end
end
