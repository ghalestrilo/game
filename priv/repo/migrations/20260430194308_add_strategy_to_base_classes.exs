defmodule Game.Repo.Migrations.AddStrategyToBaseClasses do
  use Ecto.Migration

  def change do
    alter table(:base_classes) do
      add :strategy_id, references(:strategies, on_delete: :nilify_all)
    end

    create index(:base_classes, [:strategy_id])
  end
end
