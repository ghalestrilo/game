defmodule Game.Repo.Migrations.CreateUniqueIndexNameOnDecks do
  use Ecto.Migration

  def change do
    create unique_index(:decks, [:name])
  end
end
