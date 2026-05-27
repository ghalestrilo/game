defmodule GameWeb.HomeLive do
  use GameWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "HexDecks", no_padding: true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.game_menu
      title="HexDecks"
      title_size={:large}
      options={[
        {"PVP", href: ~p"/multiplayer"},
        {"Sandbox", href: ~p"/sandbox/setup"}
      ]}
    />
    """
  end
end
