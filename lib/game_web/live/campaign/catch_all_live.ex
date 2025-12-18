defmodule GameWeb.Campaign.CatchAllLive do
  use GameWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> put_flash(:error, "Invalid campaign route. Please start from character selection.")
     |> push_navigate(to: ~p"/campaign/character-select")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex items-center justify-center h-screen">
      <p class="text-xl">Redirecting to character selection...</p>
    </div>
    """
  end
end
