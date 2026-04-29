defmodule Game.Repo.Migrations.AddAvatarUrlToBaseClasses do
  use Ecto.Migration

  def change do
    alter table(:base_classes) do
      add :avatar_url, :string
    end
  end
end
