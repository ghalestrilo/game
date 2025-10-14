defmodule GameWeb.BaseCardLive.Show do
  use GameWeb, :live_view

  alias Game.BaseCards

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

@impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:base_card, BaseCards.get_base_card!(id))}
  end

  defp page_title(:show), do: "Show Base card"
  defp page_title(:edit), do: "Edit Base card"
end
