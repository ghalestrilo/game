defmodule Game.Repo.Migrations.CreateBaseDecks do
  use Ecto.Migration

  def change do
    create table(:decks) do
      add :name, :string

      timestamps(type: :utc_datetime)
    end
  end
end
