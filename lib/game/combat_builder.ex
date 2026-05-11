defmodule Game.CombatBuilder do
  alias Game.{Character, Content, CombatState, Grid, Maps, Maps.MapTemplate}

  @default_grid_padding 4

  @doc """
  Builds a CombatState from a list of player descriptors and optional build opts.

  Each player descriptor is a map with:
    - :class     — string class name (looked up from DB)
    - :team      — integer team number
    - :position  — {q, r, s} tuple, or a spawn point atom (e.g. :team_1) when using a map
    - :id        — integer character id
    - :character — optional pre-built Character struct (skips DB lookup if present)

  Options:
    - :map — atom name of a MapTemplate from Game.Maps (nil = dynamic grid, current default)
  """
  def build(player_specs, opts \\ []) do
    map_template = resolve_map(opts[:map])
    player_specs = resolve_spawn_points(player_specs, map_template)

    characters =
      player_specs
      |> Enum.map(&build_character/1)
      |> Enum.map(&Character.draw_cards(&1, 5))

    positions = Enum.map(characters, & &1.position)

    max_radius =
      positions
      |> Enum.map(&Grid.normalize/1)
      |> Enum.map(fn {q, r, s} -> div(abs(q) + abs(r) + abs(s), 2) end)
      |> Enum.max()

    grid =
      build_grid(max_radius, map_template)
      |> then(fn g -> Enum.reduce(characters, g, &Grid.update_character(&2, &1)) end)

    %CombatState{
      state: :running,
      __constants__: %{players: characters},
      queue: characters,
      grid: grid,
      shop_cards: []
    }
    |> CombatState.initialize_queue()
    |> CombatState.setup_player_turn()
  end

  defp resolve_map(nil), do: nil
  defp resolve_map(name) when is_atom(name) or is_binary(name), do: Maps.get(name)

  defp resolve_spawn_points(specs, nil), do: specs

  defp resolve_spawn_points(specs, %MapTemplate{spawn_points: spawn_points}) do
    Enum.map(specs, fn spec ->
      case spec.position do
        pos when is_atom(pos) -> %{spec | position: Map.fetch!(spawn_points, pos)}
        pos -> %{spec | position: pos}
      end
    end)
  end

  defp build_grid(max_radius, nil) do
    padded = max_radius + @default_grid_padding
    Grid.new({padded, padded, padded})
  end

  defp build_grid(max_radius, %MapTemplate{tiles: template_tiles}) do
    padded = max_radius + @default_grid_padding
    base_grid = Grid.new({padded, padded, padded})

    overlay =
      Map.new(template_tiles, fn {coords, tile_data} ->
        base_tile = Map.get(base_grid.tiles, coords, %{terrain: :plain, occupied_by: nil})
        {coords, Map.merge(base_tile, tile_data)}
      end)

    %{base_grid | tiles: Map.merge(base_grid.tiles, overlay)}
  end

  defp build_character(%{character: char, team: team, position: position, id: id}) do
    char
    |> Map.put(:hp, Character.get_max_hp(char))
    |> Map.put(:ap, Character.get_max_ap(char))
    |> Map.put(:position, position)
    |> Map.put(:team, team)
    |> Map.put(:id, id)
    |> Map.put(:dead, false)
    |> Map.update!(:cards, fn cards ->
      all_cards = cards.draw ++ cards.hand ++ cards.discard
      %{draw: Enum.shuffle(all_cards), hand: [], discard: []}
    end)
  end

  defp build_character(%{class: class, team: team, position: position, id: id} = spec) do
    class
    |> to_string()
    |> Content.get_base_class_by_class!()
    |> Character.from_character_data()
    |> Character.shuffle_deck()
    |> Map.put(:position, position)
    |> Map.put(:team, team)
    |> Map.put(:id, id)
    |> Map.put(:dead, false)
    |> then(fn char ->
      case Map.get(spec, :name) do
        nil -> char
        name -> %{char | name: name}
      end
    end)
  end
end
