defmodule GameWeb.CharacterLive.Show do
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
     |> assign(:character, Data.get_character!(id))}
  end

  defp page_title(:show), do: "Show Character"
  defp page_title(:edit), do: "Edit Character"
end
