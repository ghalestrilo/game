defmodule Game.Repo.Migrations.CreateCharacters do
  use Ecto.Migration

  def change do
    create table(:characters) do
      add :class, :string
      add :base_hp, :integer
      add :base_ap, :integer
      add :base_movement, :integer
      add :deck_id, references(:decks, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:characters, [:deck_id])
  end
end
