defmodule GameWeb.BaseDeckLive.Index do
  use GameWeb, :live_view

  alias Game.BaseDecks
  alias Game.BaseDecks.BaseDeck

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :basedecks, BaseDecks.list_basedecks())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Base deck")
    |> assign(:base_deck, BaseDecks.get_base_deck!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Base deck")
    |> assign(:base_deck, %BaseDeck{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Basedecks")
    |> assign(:base_deck, nil)
  end

  @impl true
  def handle_info({GameWeb.BaseDeckLive.FormComponent, {:saved, base_deck}}, socket) do
    {:noreply, stream_insert(socket, :basedecks, base_deck)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    base_deck = BaseDecks.get_base_deck!(id)
    {:ok, _} = BaseDecks.delete_base_deck(base_deck)

    {:noreply, stream_delete(socket, :basedecks, base_deck)}
  end
end
