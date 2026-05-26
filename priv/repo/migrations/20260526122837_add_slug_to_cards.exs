defmodule Game.Repo.Migrations.AddSlugToCards do
  use Ecto.Migration

  def up do
    alter table(:cards) do
      add :slug, :string
    end

    execute """
    UPDATE cards
    SET slug = sub.final_slug
    FROM (
      SELECT
        id,
        CASE
          WHEN row_number() OVER (PARTITION BY base_slug ORDER BY id) = 1
          THEN base_slug
          ELSE base_slug || '-' || row_number() OVER (PARTITION BY base_slug ORDER BY id)
        END AS final_slug
      FROM (
        SELECT id,
          lower(trim(both '-' from regexp_replace(name, '[^a-zA-Z0-9]+', '-', 'g'))) AS base_slug
        FROM cards
      ) slugged
    ) sub
    WHERE cards.id = sub.id
    """

    alter table(:cards) do
      modify :slug, :string, null: false
    end

    create unique_index(:cards, [:slug])
  end

  def down do
    drop unique_index(:cards, [:slug])

    alter table(:cards) do
      remove :slug
    end
  end
end
