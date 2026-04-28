defmodule Game.Repo.Migrations.AddTargetingToCards do
  use Ecto.Migration

  def up do
    alter table(:cards) do
      add :targeting, :map, null: true
    end

    execute """
    UPDATE cards
    SET targeting = effects[1]->'targeting'
    WHERE effects IS NOT NULL
      AND array_length(effects, 1) > 0
      AND effects[1] ? 'targeting'
      AND effects[1]->'targeting' IS NOT NULL
    """

    execute """
    UPDATE cards
    SET effects = ARRAY(
      SELECT e - 'targeting'
      FROM unnest(effects) AS e
    )
    WHERE effects IS NOT NULL
      AND array_length(effects, 1) > 0
    """
  end

  def down do
    execute """
    UPDATE cards
    SET effects = (
      CASE
        WHEN array_length(effects, 1) > 0 AND targeting IS NOT NULL THEN
          ARRAY[effects[1] || jsonb_build_object('targeting', targeting)] || effects[2:]
        ELSE effects
      END
    )
    WHERE effects IS NOT NULL
    """

    alter table(:cards) do
      remove :targeting
    end
  end
end
