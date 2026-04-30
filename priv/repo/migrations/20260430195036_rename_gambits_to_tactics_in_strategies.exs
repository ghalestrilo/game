defmodule Game.Repo.Migrations.RenameGambitsToTacticsInStrategies do
  use Ecto.Migration

  def change do
    rename table(:strategies), :gambits, to: :tactics
  end
end
