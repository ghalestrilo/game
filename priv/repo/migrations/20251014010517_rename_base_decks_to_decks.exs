defmodule Game.Repo.Migrations.RenameBaseDecksToDecksAndBaseCardstoCards do
  use Ecto.Migration

  def change do
    rename table(:decks), to: table(:decks)
    rename table(:cards), to: table(:cards)
  end
end
