defmodule Game.Repo.Migrations.ModifyCharacterNameToBaeClass do
  use Ecto.Migration

  def change do
    rename table(:characters), to: table(:base_classes)
  end
end
