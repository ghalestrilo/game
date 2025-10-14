defmodule Game.Repo.Migrations.CreateBaseDeckCards do
  use Ecto.Migration

  def change do
    create table(:base_deck_cards) do
      add :count, :integer
      add :deck_id, references(:decks, on_delete: :nothing)
      add :card_id, references(:cards, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:base_deck_cards, [:deck_id])
    create index(:base_deck_cards, [:card_id])
  end
end
