defmodule GameWeb.Admin.AdminMenuLive do
  use GameWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, menu: get_menu())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Admin Pages
      <:subtitle>Manage all admin sections from here.</:subtitle>
    </.header>
    <ul class="space-y-4 mt-8">
      <%= for item <- @menu do %>
        <li>
          <.link navigate={item.route} class="text-lg font-medium text-blue-600 hover:underline">
            {item.label}
          </.link>
        </li>
      <% end %>
    </ul>
    """
  end

  def get_menu() do
    [
      %{
        route: ~p"/admin/base_classes",
        label: "Base Classes"
      },
      %{
        route: ~p"/admin/basedecks",
        label: "Base Decks"
      },
      %{
        route: ~p"/admin/basecards",
        label: "Base Cards"
      }
    ]
  end
end
