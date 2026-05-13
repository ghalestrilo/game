defmodule Game.Maps.MapTemplate do
  @type t() :: %__MODULE__{
          name: atom() | String.t(),
          display_name: String.t(),
          tiles: %{{integer(), integer(), integer()} => %{terrain: atom(), objects: list()}},
          spawn_points: %{atom() => {integer(), integer(), integer()}}
        }

  defstruct name: nil,
            display_name: nil,
            tiles: %{},
            spawn_points: %{}
end

defmodule Game.Maps do
  import Ecto.Query, warn: false
  alias Game.Repo
  alias Game.Maps.{Map, MapTemplate}
  alias Game.MapObject

  # Hardcoded maps compiled at load time — extend or override with DB records.
  @builtin_maps %{
    "two_towers" => %MapTemplate{
      name: "two_towers",
      display_name: "Two Towers",
      tiles:
        (for q <- -4..4, r <- -4..4, s <- -4..4, q + r + s == 0, into: %{} do
           objects =
             if {q, r, s} in [{0, 0, 0}, {1, 0, -1}, {-1, 0, 1}],
               do: [%MapObject.Wall{}],
               else: []

           {{q, r, s}, %{terrain: :plain, objects: objects}}
         end),
      spawn_points: %{
        team_1: {-3, 0, 3},
        team_2: {3, 0, -3}
      }
    }
  }

  @doc """
  Returns a MapTemplate by slug. Checks the DB first; falls back to builtin maps.
  Returns nil if not found anywhere.
  """
  def get(slug) when is_atom(slug), do: get(Atom.to_string(slug))

  def get(slug) when is_binary(slug) do
    case Repo.get_by(Map, slug: slug) do
      nil -> Elixir.Map.get(@builtin_maps, slug)
      db_map -> from_db(db_map)
    end
  end

  @doc "Lists all available map slugs (builtin only — DB maps require a separate query)."
  def list, do: Elixir.Map.keys(@builtin_maps)

  @doc "Returns all maps from the DB."
  def list_db, do: Repo.all(Map)

  @doc "Creates a map record in the DB."
  def create_map(attrs \\ %{}) do
    %Map{}
    |> Map.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Gets a DB map by id, raising if not found."
  def get_map!(id), do: Repo.get!(Map, id)

  @doc "Updates a DB map record."
  def update_map(%Map{} = map, attrs) do
    map
    |> Map.changeset(attrs)
    |> Repo.update()
  end

  @doc "Deletes a DB map record."
  def delete_map(%Map{} = map), do: Repo.delete(map)

  @doc "Converts a DB Map record into a MapTemplate, deserializing tile and spawn_point data."
  def from_db(%Map{} = db_map) do
    tiles =
      Elixir.Map.new(db_map.tiles, fn tile ->
        coords = {tile["q"], tile["r"], tile["s"]}
        terrain = String.to_existing_atom(tile["terrain"] || "plain")
        objects = deserialize_objects(tile["objects"] || [])
        {coords, %{terrain: terrain, objects: objects}}
      end)

    spawn_points =
      Elixir.Map.new(db_map.spawn_points, fn {key, [q, r, s]} ->
        {String.to_atom(key), {q, r, s}}
      end)

    %MapTemplate{
      name: db_map.slug,
      display_name: db_map.display_name,
      tiles: tiles,
      spawn_points: spawn_points
    }
  end

  defp deserialize_objects(objects) do
    Enum.map(objects, fn
      %{"type" => "wall"} -> %MapObject.Wall{}
      %{"type" => "pickup", "item" => item, "quantity" => qty} ->
        %MapObject.Pickup{item: String.to_existing_atom(item), quantity: qty}
      %{"type" => "breakable", "hp" => hp, "max_hp" => max_hp, "blocks_movement" => blocks} ->
        %MapObject.Breakable{hp: hp, max_hp: max_hp, blocks_movement: blocks}
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end
end
