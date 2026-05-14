defmodule GameWeb.HelloThreeJsLive do
  use GameWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    tiles =
      case Game.Maps.list_db() do
        [first | _] ->
          map = Game.Maps.from_db(first)
          map.tiles
        |> Enum.map(fn {{q, r, s}, %{objects: objects}} ->
          %{q: q, r: r, s: s, has_object: objects != []}
        end)

        [] ->
          [%{q: 0, r: 0, s: 0, has_object: false}]
      end

    {:ok, push_event(socket, "load_map", %{tiles: tiles})}
  end

  @impl true
  def handle_event("randomize_cube", _params, socket) do
    size = :rand.uniform() * 1.5 + 0.25
    x = (:rand.uniform() - 0.5) * 4
    y = (:rand.uniform() - 0.5) * 4

    {:noreply, push_event(socket, "randomize_cube", %{size: size, x: x, y: y})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="position: relative; width: 100vw; height: 100vh;">
      <div id="three-js-container" phx-hook="ThreeJS" style="width: 100%; height: 100%;"></div>
      <div style="position: absolute; top: 1.5rem; right: 1.5rem; z-index: 10;">
        <button phx-click="randomize_cube" style="padding: 0.5rem 1.25rem; background: rgba(255,255,255,0.15); color: white; border: 1px solid rgba(255,255,255,0.4); border-radius: 0.5rem; cursor: pointer; backdrop-filter: blur(4px); font-size: 0.9rem;">
          Randomize Cube
        </button>
      </div>
    </div>
    """
  end
end
