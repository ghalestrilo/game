defmodule GameWeb.MultiplayerLive do
  use GameWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "PVP", no_padding: true)}
  end

  @impl true
  def handle_event("create_lobby", _params, socket) do
    {:ok, id} = Game.Lobby.create()
    {:noreply, push_navigate(socket, to: ~p"/multiplayer/#{id}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.game_menu
      title="PVP"
      title_size={:regular}
      options={[{"Create Lobby", "phx-click": "create_lobby"}]}
    />
    """
  end
end
