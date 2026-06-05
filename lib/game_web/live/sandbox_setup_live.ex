defmodule GameWeb.SandboxSetupLive do
  use GameWeb, :live_view

  alias Game.{Content, Maps}

  @impl true
  def mount(_params, _session, socket) do
    classes = Content.list_playable_classes()
    db_maps = Maps.list_db()

    map_options =
      [{"Blank (no map)", ""}] ++
        Enum.map(db_maps, &{&1.display_name, &1.slug})

    {:ok,
     assign(socket,
       page_title: "Sandbox",
       classes: classes,
       map_options: map_options,
       selected_map: "",
       selected_class: "",
       characters: [],
       render_3d: true
     )}
  end

  @impl true
  def handle_event("select_map", %{"map" => map}, socket) do
    {:noreply, assign(socket, selected_map: map)}
  end

  @impl true
  def handle_event("add_character", %{"class" => ""}, socket), do: {:noreply, socket}

  @impl true
  def handle_event("add_character", %{"class" => class}, socket) do
    {:noreply, assign(socket, characters: socket.assigns.characters ++ [class])}
  end

  @impl true
  def handle_event("remove_character", %{"index" => index}, socket) do
    idx = String.to_integer(index)
    updated = List.delete_at(socket.assigns.characters, idx)
    {:noreply, assign(socket, characters: updated)}
  end

  @impl true
  def handle_event("toggle_3d", _params, socket) do
    {:noreply, assign(socket, render_3d: !socket.assigns.render_3d)}
  end

  @impl true
  def handle_event("start_sandbox", _params, socket) do
    if length(socket.assigns.characters) < 2 do
      {:noreply, put_flash(socket, :error, "Add at least 2 characters")}
    else
      params =
        %{characters: Enum.join(socket.assigns.characters, ",")}
        |> then(fn p ->
          if socket.assigns.selected_map != "",
            do: Map.put(p, :map, socket.assigns.selected_map),
            else: p
        end)
        |> then(fn p ->
          if socket.assigns.render_3d, do: Map.put(p, "3d", "true"), else: p
        end)

      {:noreply, push_navigate(socket, to: ~p"/sandbox?#{params}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center min-h-screen gap-8 p-8">
      <h1 class="text-3xl font-bold">Sandbox Setup</h1>

      <div class="flex flex-col gap-6 w-full max-w-md">
        
    <!-- Map selector -->
        <div class="flex flex-col gap-2">
          <label class="font-semibold">Map</label>
          <form phx-change="select_map">
            <select class="select select-bordered w-full" name="map">
              <%= for {label, value} <- @map_options do %>
                <option value={value} selected={value == @selected_map}>{label}</option>
              <% end %>
            </select>
          </form>
        </div>
        
    <!-- Character list -->
        <div class="flex flex-col gap-2">
          <label class="font-semibold">
            Characters
            <span class="text-base-content/50 font-normal text-sm ml-1">
              ({length(@characters)} added)
            </span>
          </label>

          <div :if={@characters == []} class="text-base-content/40 text-sm italic">
            No characters yet — add some below
          </div>

          <ul class="flex flex-col gap-2">
            <%= for {class, idx} <- Enum.with_index(@characters) do %>
              <li class="flex items-center justify-between bg-base-200 rounded-lg px-4 py-2">
                <span class="capitalize font-medium">{class}</span>
                <span class="text-base-content/40 text-xs mr-auto ml-3">
                  team {rem(idx, 2) + 1}
                </span>
                <button
                  phx-click="remove_character"
                  phx-value-index={idx}
                  class="btn btn-ghost btn-xs text-error"
                  aria-label="Remove"
                >
                  ✕
                </button>
              </li>
            <% end %>
          </ul>
        </div>
        
    <!-- Class selector — form wrapper required for phx-change to fire -->
        <form phx-change="add_character">
          <select class="select select-bordered w-full" name="class">
            <option value="" selected>Add a character...</option>
            <%= for bc <- @classes do %>
              <option value={bc.class}>{String.capitalize(bc.class)}</option>
            <% end %>
          </select>
        </form>
        
    <!-- 3D toggle -->
        <div class="flex items-center justify-between">
          <label class="font-semibold">3D renderer</label>
          <input
            type="checkbox"
            class="checkbox"
            checked={@render_3d}
            phx-click="toggle_3d"
          />
        </div>
        
    <!-- Start button -->
        <button
          phx-click="start_sandbox"
          class="btn btn-primary btn-lg w-full"
          disabled={length(@characters) < 2}
        >
          Start
        </button>

        <a href={~p"/"} class="btn btn-ghost w-full">Back</a>
      </div>
    </div>
    """
  end
end
