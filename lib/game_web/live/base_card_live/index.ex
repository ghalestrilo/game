defmodule GameWeb.BaseCardLive.Index do
  use GameWeb, :live_view

  alias Game.BaseCards
  alias Game.BaseCards.BaseCard

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :basecards, BaseCards.list_basecards())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Base card")
    |> assign(:base_card, BaseCards.get_base_card!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Base card")
    |> assign(:base_card, %BaseCard{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Basecards")
    |> assign(:base_card, nil)
  end

  @impl true
  def handle_info({GameWeb.BaseCardLive.FormComponent, {:saved, base_card}}, socket) do
    {:noreply, stream_insert(socket, :basecards, base_card)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    base_card = BaseCards.get_base_card!(id)
    {:ok, _} = BaseCards.delete_base_card(base_card)

    {:noreply, stream_delete(socket, :basecards, base_card)}
  end
end
