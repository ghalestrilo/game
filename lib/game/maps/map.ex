defmodule Game.Maps.Map do
  use Ecto.Schema
  import Ecto.Changeset

  schema "maps" do
    field :slug, :string
    field :display_name, :string
    # Each entry: %{"q" => int, "r" => int, "s" => int, "terrain" => string, "objects" => [...]}
    field :tiles, {:array, :map}, default: []
    # %{"team_1" => [q, r, s], "team_2" => [q, r, s], ...}
    field :spawn_points, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  def changeset(map, attrs) do
    map
    |> cast(attrs, [:slug, :display_name, :tiles, :spawn_points])
    |> validate_required([:slug, :display_name])
    |> unique_constraint(:slug)
  end
end
