defmodule Game.Repo.Migrations.CreateBasedeckcards do
  use Ecto.Migration

  def change do
    create table(:basedeckcards) do
      add :count, :integer
      add :deck_id, references(:basedecks, on_delete: :nothing)
      add :card_id, references(:basecards, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:basedeckcards, [:deck_id])
    create index(:basedeckcards, [:card_id])
  end
end
