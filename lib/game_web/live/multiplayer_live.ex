defmodule GameWeb.MultiplayerLive do
  use GameWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_event("create_lobby", _params, socket) do
    {:ok, id} = Game.Lobby.create()
    {:noreply, push_navigate(socket, to: ~p"/multiplayer/#{id}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-screen justify-center items-center gap-4">
      <h1 class="text-2xl font-bold">PVP Lobby</h1>
      <button
        phx-click="create_lobby"
        class="px-4 py-2 rounded-2 bg-primary text-primary"
      >
        Create Lobby
      </button>
    </div>
    """
  end
end
