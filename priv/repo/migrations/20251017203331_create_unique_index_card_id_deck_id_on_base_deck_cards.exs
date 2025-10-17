defmodule Game.Repo.Migrations.CreateUniqueIndexCardIdDeckIdOnBaseDeckCards do
  use Ecto.Migration

  def change do
    create unique_index(:base_deck_cards, [:deck_id, :card_id])
  end
end
