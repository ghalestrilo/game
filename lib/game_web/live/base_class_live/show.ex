defmodule GameWeb.BaseClassLive.Show do
  use GameWeb, :live_view

  alias Game.Data

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:base_class, Content.get_base_class!(id))}
  end

  defp page_title(:show), do: "Show Character"
  defp page_title(:edit), do: "Edit Character"
end
