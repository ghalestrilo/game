defmodule GameWeb.Admin.HomeLive do
  use GameWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-8">
      <h1 class="text-2xl font-bold mb-6">Admin</h1>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <.link
          navigate={~p"/admin/base_cards"}
          class="card bg-base-200 hover:bg-base-300 transition-colors"
        >
          <div class="card-body">
            <Backpex.HTML.CoreComponents.icon name="hero-rectangle-stack" class="size-8 mb-2" />
            <h2 class="card-title">Base Cards</h2>
            <p class="text-sm opacity-70">Manage card definitions and effects</p>
          </div>
        </.link>
        <.link
          navigate={~p"/admin/base_decks"}
          class="card bg-base-200 hover:bg-base-300 transition-colors"
        >
          <div class="card-body">
            <Backpex.HTML.CoreComponents.icon name="hero-squares-2x2" class="size-8 mb-2" />
            <h2 class="card-title">Base Decks</h2>
            <p class="text-sm opacity-70">Manage starter decks for each class</p>
          </div>
        </.link>
        <.link
          navigate={~p"/admin/base_classes"}
          class="card bg-base-200 hover:bg-base-300 transition-colors"
        >
          <div class="card-body">
            <Backpex.HTML.CoreComponents.icon name="hero-user-group" class="size-8 mb-2" />
            <h2 class="card-title">Base Classes</h2>
            <p class="text-sm opacity-70">Manage playable character classes</p>
          </div>
        </.link>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
