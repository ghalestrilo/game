defmodule GameWeb.Admin.MapEditorLive do
  use GameWeb, :live_view

  alias Game.{CombatState, Maps}

  @editor_padding 2
  @editor_min_radius 3

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    map = Maps.get_map!(id)

    {:ok,
     socket
     |> assign(
       map: map,
       pending_tiles: map.tiles,
       pending_spawn_points: map.spawn_points,
       selected_tool: :wall,
       dirty: false
     )
     |> assign_grid(map)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 relative">
      <div class="flex items-center gap-4 mb-6">
        <button
          class="btn btn-ghost btn-sm"
          phx-click={if @dirty, do: show_modal("exit-modal"), else: JS.navigate("/admin/maps")}
        >
          <Backpex.HTML.CoreComponents.icon name="hero-arrow-left" class="h-4 w-4" /> Maps
        </button>
        <h1 class="text-2xl font-bold">{@map.display_name}</h1>
        <span class="text-base-content/50 text-sm font-mono">{@map.slug}</span>
        <div class="ml-auto flex items-center gap-3">
          <span :if={@dirty} class="text-sm text-warning">Unsaved changes</span>
          <button class="btn btn-primary btn-sm" phx-click="save" disabled={not @dirty}>
            Save
          </button>
        </div>
      </div>

      <.live_component
        module={GameWeb.GameBoard}
        id="map-editor-board"
        game_state={editor_game_state(@grid)}
        current_player={nil}
        static_map={true}
        context={:edit}
        spawn_points={@spawn_points}
      />
      
    <!-- FAB tool selector -->
      <div class="fab fixed bottom-8 right-8 !items-end">
        <div tabindex="0" role="button" class="btn btn-lg btn-circle btn-neutral">
          <Backpex.HTML.CoreComponents.icon name={tool_icon(@selected_tool)} class="h-6 w-6" />
        </div>
        <button
          class={["btn btn-lg gap-2", @selected_tool == :wall && "btn-active"]}
          phx-click="select_tool"
          phx-value-tool="wall"
        >
          <Backpex.HTML.CoreComponents.icon name="hero-cube" class="h-5 w-5" /> Wall
        </button>
        <button
          class={["btn btn-lg gap-2", @selected_tool == :spawn_point && "btn-active"]}
          phx-click="select_tool"
          phx-value-tool="spawn_point"
        >
          <Backpex.HTML.CoreComponents.icon name="hero-map-pin" class="h-5 w-5" /> Spawn Point
        </button>
        <button
          class={["btn btn-lg gap-2", @selected_tool == :terrain && "btn-active"]}
          phx-click="select_tool"
          phx-value-tool="terrain"
        >
          <Backpex.HTML.CoreComponents.icon name="hero-square-2-stack" class="h-5 w-5" /> Terrain
        </button>
      </div>

      <.modal id="exit-modal">
        <div class="flex flex-col gap-4">
          <h3 class="text-lg font-bold">Unsaved changes</h3>
          <p>You have unsaved changes. Leave without saving?</p>
          <div class="flex justify-end gap-3">
            <button class="btn btn-ghost btn-sm" phx-click={hide_modal("exit-modal")}>
              Stay
            </button>
            <button class="btn btn-error btn-sm" phx-click="discard_and_exit">
              Leave without saving
            </button>
          </div>
        </div>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event("select_tool", %{"tool" => tool}, socket) do
    {:noreply, assign(socket, selected_tool: String.to_existing_atom(tool))}
  end

  @impl true
  def handle_event("interact", %{"target_position" => pos_str}, socket) do
    handle_tile_click(pos_str, socket)
  end

  @impl true
  def handle_event("save", _params, socket) do
    {:ok, map} =
      Maps.update_map(socket.assigns.map, %{
        tiles: socket.assigns.pending_tiles,
        spawn_points: socket.assigns.pending_spawn_points
      })

    {:noreply, assign(socket, map: map, dirty: false)}
  end

  @impl true
  def handle_event("discard_and_exit", _params, socket) do
    {:noreply, push_navigate(socket, to: "/admin/maps")}
  end

  @impl true
  def handle_info({:parent_event, "interact", %{"target_position" => pos_str}}, socket) do
    handle_tile_click(pos_str, socket)
  end

  def handle_info({:parent_event, _event, _params}, socket), do: {:noreply, socket}

  defp handle_tile_click(pos_str, socket) do
    coord = parse_coord(pos_str)
    grid_tile = get_in(socket.assigns.grid.tiles, [coord])
    oob? = is_nil(grid_tile) or grid_tile[:terrain] == nil

    {pending_tiles, pending_spawn_points} =
      case socket.assigns.selected_tool do
        :wall when not oob? ->
          apply_wall_toggle(
            coord,
            socket.assigns.pending_tiles,
            socket.assigns.pending_spawn_points
          )

        :spawn_point when not oob? ->
          apply_spawn_toggle(
            coord,
            socket.assigns.pending_tiles,
            socket.assigns.pending_spawn_points
          )

        :terrain ->
          apply_terrain_toggle(
            coord,
            oob?,
            socket.assigns.pending_tiles,
            socket.assigns.pending_spawn_points
          )

        _ ->
          {socket.assigns.pending_tiles, socket.assigns.pending_spawn_points}
      end

    map = %{socket.assigns.map | tiles: pending_tiles, spawn_points: pending_spawn_points}

    {:noreply,
     socket
     |> assign(
       pending_tiles: pending_tiles,
       pending_spawn_points: pending_spawn_points,
       dirty: true
     )
     |> assign_grid(map)}
  end

  # Toggles a wall on the tile. Clears any spawn point occupying this coord first.
  defp apply_wall_toggle({q, r, s} = coord, tiles, spawn_points) do
    spawn_points = remove_spawn_at(spawn_points, coord)
    tiles = toggle_wall_in_tiles(tiles, q, r, s)
    {tiles, spawn_points}
  end

  # Toggles a spawn point. If one exists at this coord, removes it.
  # If not, assigns the next free team slot and clears any wall on that tile.
  defp apply_spawn_toggle({q, r, s} = coord, tiles, spawn_points) do
    if spawn_at?(spawn_points, coord) do
      {tiles, remove_spawn_at(spawn_points, coord)}
    else
      next_team = next_team_key(spawn_points)
      tiles = clear_walls_in_tile(tiles, q, r, s)
      spawn_points = Elixir.Map.put(spawn_points, next_team, [q, r, s])
      {tiles, spawn_points}
    end
  end

  # oob? comes from the rendered grid tile — more reliable than checking pending_tiles,
  # since OOB tiles exist in the grid but are never in pending_tiles.
  defp apply_terrain_toggle({q, r, s} = _coord, _oob? = true, tiles, spawn_points) do
    new_tile = %{"q" => q, "r" => r, "s" => s, "terrain" => "plain", "objects" => []}
    {[new_tile | tiles], spawn_points}
  end

  defp apply_terrain_toggle({q, r, s} = coord, _oob? = false, tiles, spawn_points) do
    idx = Enum.find_index(tiles, &(&1["q"] == q and &1["r"] == r and &1["s"] == s))
    tiles = if idx, do: List.delete_at(tiles, idx), else: tiles
    {tiles, remove_spawn_at(spawn_points, coord)}
  end

  defp parse_coord(pos_str) do
    [q, r, s] = pos_str |> String.split("_") |> Enum.map(&String.to_integer/1)
    {q, r, s}
  end

  defp spawn_at?(spawn_points, {q, r, s}) do
    Enum.any?(spawn_points, fn {_team, coords} -> coords == [q, r, s] end)
  end

  defp remove_spawn_at(spawn_points, {q, r, s}) do
    Elixir.Map.reject(spawn_points, fn {_team, coords} -> coords == [q, r, s] end)
  end

  # Returns the next team key string ("team_1", "team_2", ...) not yet in use.
  defp next_team_key(spawn_points) do
    existing = Elixir.Map.keys(spawn_points) |> Enum.map(&to_string/1) |> MapSet.new()

    Stream.iterate(1, &(&1 + 1))
    |> Stream.map(&"team_#{&1}")
    |> Enum.find(&(not MapSet.member?(existing, &1)))
  end

  defp toggle_wall_in_tiles(tiles, q, r, s) do
    case Enum.find_index(tiles, &(&1["q"] == q and &1["r"] == r and &1["s"] == s)) do
      nil ->
        [
          %{
            "q" => q,
            "r" => r,
            "s" => s,
            "terrain" => "plain",
            "objects" => [%{"type" => "wall"}]
          }
          | tiles
        ]

      idx ->
        List.update_at(tiles, idx, &toggle_wall_object/1)
    end
  end

  defp clear_walls_in_tile(tiles, q, r, s) do
    case Enum.find_index(tiles, &(&1["q"] == q and &1["r"] == r and &1["s"] == s)) do
      nil -> tiles
      idx -> List.update_at(tiles, idx, &Elixir.Map.put(&1, "objects", []))
    end
  end

  defp toggle_wall_object(%{"objects" => objects} = tile) do
    updated =
      if Enum.any?(objects, &(&1["type"] == "wall")) do
        Enum.reject(objects, &(&1["type"] == "wall"))
      else
        [%{"type" => "wall"} | objects]
      end

    %{tile | "objects" => updated}
  end

  defp toggle_wall_object(tile), do: Elixir.Map.put(tile, "objects", [%{"type" => "wall"}])

  defp assign_grid(socket, map) do
    spawn_points = deserialize_spawn_points(map.spawn_points)
    assign(socket, grid: build_grid(map), spawn_points: spawn_points)
  end

  defp build_grid(map) do
    template = Maps.from_db(map)
    radius = content_radius(map) + @editor_padding

    # Base tiles have no terrain — they are empty/OOB cells used only for editor rendering.
    base_tiles =
      for q <- -radius..radius,
          r <- -radius..radius,
          s <- -radius..radius,
          q + r + s == 0,
          into: %{} do
        {Game.Grid.normalize({q, r, s}), %{terrain: nil, occupied_by: nil}}
      end

    overlay =
      Elixir.Map.new(template.tiles, fn {coords, tile_data} ->
        base_tile = Elixir.Map.get(base_tiles, coords, %{terrain: nil, occupied_by: nil})
        {coords, Elixir.Map.merge(base_tile, tile_data)}
      end)

    %Game.Grid{tiles: Elixir.Map.merge(base_tiles, overlay)}
  end

  defp content_radius(map) do
    tile_coords = Enum.map(map.tiles, &{&1["q"], &1["r"], &1["s"]})

    spawn_coords =
      Enum.map(map.spawn_points, fn {_team, [q, r, s]} -> {q, r, s} end)

    case tile_coords ++ spawn_coords do
      [] ->
        @editor_min_radius

      coords ->
        coords
        |> Enum.map(fn {q, r, s} -> div(abs(q) + abs(r) + abs(s), 2) end)
        |> Enum.max()
        |> max(@editor_min_radius)
    end
  end

  defp deserialize_spawn_points(spawn_points) do
    Elixir.Map.new(spawn_points, fn {team, [q, r, s]} ->
      {String.to_atom(team), {q, r, s}}
    end)
  end

  defp editor_game_state(grid) do
    %{combat: %CombatState{grid: grid, state: :initialized}}
  end

  defp tool_icon(:wall), do: "hero-cube"
  defp tool_icon(:spawn_point), do: "hero-map-pin"
  defp tool_icon(:terrain), do: "hero-square-2-stack"
end
