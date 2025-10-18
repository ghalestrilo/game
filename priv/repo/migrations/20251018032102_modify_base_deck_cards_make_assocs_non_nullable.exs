defmodule Game.Repo.Migrations.ModifyBaseDeckCardsMakeAssocsNonNullable do
  use Ecto.Migration

  def change do
    alter table(:base_deck_cards) do
      modify :deck_id, references(:decks, on_delete: :nothing),
        null: false,
        from: references(:decks, on_delete: :nothing)

      modify :card_id, references(:cards, on_delete: :nothing),
        null: false,
        from: references(:cards, on_delete: :nothing)
    end
  end
end
