defmodule GameWeb.Admin.MapEditorLive do
  use GameWeb, :live_view

  alias Game.{CombatState, Grid, Maps}

  @editor_radius 4

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    map = Maps.get_map!(id)

    {:ok,
     socket
     |> assign(map: map, pending_tiles: map.tiles, dirty: false, show_exit_modal: false)
     |> assign_grid(map.tiles)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6">
      <div class="flex items-center gap-4 mb-6">
        <button class="btn btn-ghost btn-sm" phx-click="maybe_exit">
          <Backpex.HTML.CoreComponents.icon name="hero-arrow-left" class="h-4 w-4" />
          Maps
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
      <p class="text-sm text-base-content/60 mb-4">Click a tile to toggle a wall.</p>
      <.live_component
        module={GameWeb.GameBoard}
        id="map-editor-board"
        game_state={editor_game_state(@grid)}
        current_player={nil}
        static_map={true}
      />

      <.modal id="exit-modal" show={@show_exit_modal}>
        <div class="flex flex-col gap-4">
          <h3 class="text-lg font-bold">Unsaved changes</h3>
          <p>You have unsaved changes. Leave without saving?</p>
          <div class="flex justify-end gap-3">
            <button class="btn btn-ghost btn-sm" phx-click="close_exit_modal">
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
  def handle_event("interact", %{"target_position" => pos_str}, socket) do
    handle_tile_click(pos_str, socket)
  end

  @impl true
  def handle_event("save", _params, socket) do
    {:ok, map} = Maps.update_map(socket.assigns.map, %{tiles: socket.assigns.pending_tiles})
    {:noreply, assign(socket, map: map, dirty: false)}
  end

  @impl true
  def handle_event("maybe_exit", _params, socket) do
    if socket.assigns.dirty do
      {:noreply, assign(socket, show_exit_modal: true)}
    else
      {:noreply, push_navigate(socket, to: "/admin/maps")}
    end
  end

  @impl true
  def handle_event("close_exit_modal", _params, socket) do
    {:noreply, assign(socket, show_exit_modal: false)}
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
    [q, r, s] = pos_str |> String.split("_") |> Enum.map(&String.to_integer/1)
    pending_tiles = toggle_wall_in_tiles(socket.assigns.pending_tiles, {q, r, s})

    {:noreply,
     socket
     |> assign(pending_tiles: pending_tiles, dirty: true)
     |> assign_grid(pending_tiles)}
  end

  defp assign_grid(socket, tiles) do
    assign(socket, grid: build_grid(tiles))
  end

  defp toggle_wall_in_tiles(tiles, {q, r, s}) do
    case Enum.find_index(tiles, &(&1["q"] == q and &1["r"] == r and &1["s"] == s)) do
      nil ->
        [%{"q" => q, "r" => r, "s" => s, "terrain" => "plain", "objects" => [%{"type" => "wall"}]} | tiles]

      idx ->
        List.update_at(tiles, idx, &toggle_wall_object/1)
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

  defp build_grid(tiles) do
    template = Maps.from_db(%Game.Maps.Map{tiles: tiles, spawn_points: %{}})
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
