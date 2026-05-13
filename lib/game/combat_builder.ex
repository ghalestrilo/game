defmodule Game.CombatBuilder do
  alias Game.{Character, Content, CombatState, Grid, Maps, Maps.MapTemplate}

  @default_grid_padding 4

  @doc """
  Builds a CombatState from a list of player descriptors and optional build opts.

  Each player descriptor is a map with:
    - :class     — string class name (looked up from DB)
    - :team      — integer team number
    - :position  — {q, r, s} tuple, or omitted (auto-assigned from map spawn points / free tiles)
    - :id        — integer character id
    - :character — optional pre-built Character struct (skips DB lookup if present)

  Options:
    - :map — atom or string slug of a MapTemplate from Game.Maps (nil = dynamic grid)
    - :settings — lobby settings map; `:map` key used if `:map` opt is absent
  """
  def build(player_specs, opts \\ []) do
    map_template = resolve_map(opts[:map] || get_in(opts[:settings], [:map]))
    dbg(map_template)
    player_specs = maybe_assign_positions(player_specs, map_template)

    characters =
      player_specs
      |> Enum.map(&build_character/1)
      |> Enum.map(&Character.draw_cards(&1, 5))

    positions = Enum.map(characters, & &1.position)

    template_coords =
      case map_template do
        %MapTemplate{tiles: tiles, spawn_points: sp} ->
          Elixir.Map.keys(tiles) ++ Elixir.Map.values(sp)
        nil ->
          []
      end

    max_radius =
      (positions ++ template_coords)
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

  # If any spec is missing :position, auto-assign all of them.
  defp maybe_assign_positions(specs, map_template) do
    if Enum.any?(specs, &(not Map.has_key?(&1, :position))) do
      assign_positions(specs, map_template)
    else
      specs
    end
  end

  # Fills :position for each spec: spawn points first, then :random sentinels for overflow.
  # Random sentinels are resolved against a temporary plain grid.
  defp assign_positions(specs, map_template) do
    spawn_coords = spawn_point_coords(map_template)

    specs_with_sentinels =
      specs
      |> Enum.with_index()
      |> Enum.map(fn {spec, i} ->
        Map.put(spec, :position, Enum.at(spawn_coords, i, :random))
      end)

    resolve_random_positions(specs_with_sentinels, map_template)
  end

  defp spawn_point_coords(nil), do: []
  defp spawn_point_coords(%MapTemplate{spawn_points: sp}), do: Map.values(sp)

  # Substitutes :random sentinels with actual free tile coordinates.
  defp resolve_random_positions(specs, map_template) do
    taken =
      specs
      |> Enum.map(& &1.position)
      |> Enum.reject(&(&1 == :random))
      |> MapSet.new()

    # Estimate radius from taken positions, defaulting to padding radius when all are :random.
    base_radius =
      if MapSet.size(taken) > 0 do
        taken
        |> Enum.map(&Grid.normalize/1)
        |> Enum.map(fn {q, r, s} -> div(abs(q) + abs(r) + abs(s), 2) end)
        |> Enum.max()
      else
        @default_grid_padding
      end

    scratch_grid = build_grid(base_radius, map_template)

    free_tiles =
      scratch_grid.tiles
      |> Enum.reject(fn {coord, tile} ->
        MapSet.member?(taken, coord) or Grid.tile_blocked?(%Grid{tiles: scratch_grid.tiles}, coord)
      end)
      |> Enum.map(fn {coord, _} -> coord end)
      |> Enum.shuffle()

    {resolved_specs, _remaining} =
      Enum.map_reduce(specs, free_tiles, fn spec, available ->
        if spec.position == :random do
          [next | rest] = available
          {%{spec | position: next}, rest}
        else
          {spec, available}
        end
      end)

    resolved_specs
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
