defmodule GameWeb.Admin.MapEditorLive do
  use GameWeb, :live_view

  alias Game.{CombatState, Grid, Maps}

  @editor_radius 4

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    map = Maps.get_map!(id)
    {:ok, assign(socket, map: map, grid: build_grid(map))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6">
      <div class="flex items-center gap-4 mb-6">
        <a href="/admin/maps" class="btn btn-ghost btn-sm">
          <Backpex.HTML.CoreComponents.icon name="hero-arrow-left" class="h-4 w-4" />
          Maps
        </a>
        <h1 class="text-2xl font-bold">{@map.display_name}</h1>
        <span class="text-base-content/50 text-sm font-mono">{@map.slug}</span>
      </div>
      <p class="text-sm text-base-content/60 mb-4">Click a tile to toggle a wall.</p>
      <.live_component
        module={GameWeb.GameBoard}
        id="map-editor-board"
        game_state={editor_game_state(@grid)}
        current_player={nil}
      />
    </div>
    """
  end

  @impl true
  def handle_event("interact", %{"target_position" => pos_str}, socket) do
    handle_tile_click(pos_str, socket)
  end

  @impl true
  def handle_info({:parent_event, "interact", %{"target_position" => pos_str}}, socket) do
    handle_tile_click(pos_str, socket)
  end

  def handle_info({:parent_event, _event, _params}, socket), do: {:noreply, socket}

  defp handle_tile_click(pos_str, socket) do
    [q, r, s] = pos_str |> String.split("_") |> Enum.map(&String.to_integer/1)
    map = toggle_wall(socket.assigns.map, {q, r, s})
    {:noreply, assign(socket, map: map, grid: build_grid(map))}
  end

  defp toggle_wall(map, {q, r, s}) do
    tiles =
      case Enum.find_index(map.tiles, &(&1["q"] == q and &1["r"] == r and &1["s"] == s)) do
        nil ->
          [new_tile(q, r, s, [%{"type" => "wall"}]) | map.tiles]

        idx ->
          List.update_at(map.tiles, idx, &toggle_wall_in_tile/1)
      end

    {:ok, updated} = Maps.update_map(map, %{tiles: tiles})
    updated
  end

  defp toggle_wall_in_tile(%{"objects" => objects} = tile) do
    has_wall = Enum.any?(objects, &(&1["type"] == "wall"))

    updated_objects =
      if has_wall do
        Enum.reject(objects, &(&1["type"] == "wall"))
      else
        [%{"type" => "wall"} | objects]
      end

    %{tile | "objects" => updated_objects}
  end

  defp toggle_wall_in_tile(tile), do: Elixir.Map.put(tile, "objects", [%{"type" => "wall"}])

  defp new_tile(q, r, s, objects) do
    %{"q" => q, "r" => r, "s" => s, "terrain" => "plain", "objects" => objects}
  end

  defp build_grid(map) do
    template = Maps.from_db(map)
    base = Grid.new({@editor_radius, @editor_radius, @editor_radius})

    overlay =
      Elixir.Map.new(template.tiles, fn {coords, tile_data} ->
        base_tile = Elixir.Map.get(base.tiles, coords, %{terrain: :plain, occupied_by: nil})
        {coords, Elixir.Map.merge(base_tile, tile_data)}
      end)

    %{base | tiles: Elixir.Map.merge(base.tiles, overlay)}
  end

  defp editor_game_state(grid) do
    %{combat: %CombatState{grid: grid, state: :initialized}}
  end
end
