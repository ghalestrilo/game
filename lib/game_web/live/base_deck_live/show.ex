defmodule GameWeb.BaseDeckLive.Show do
  use GameWeb, :live_view

  alias Game.BaseDecks

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:base_deck, BaseDecks.get_base_deck!(id))}
  end

  defp page_title(:show), do: "Show Base deck"
  defp page_title(:edit), do: "Edit Base deck"
end
