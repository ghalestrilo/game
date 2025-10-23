defmodule GameWeb.BaseClassLive.Index do
  use GameWeb, :live_view

  alias Game.Content
  alias Game.Content.BaseClass

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :base_classes, Content.list_base_classes())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit BaseClass")
    |> assign(:base_class, Content.get_base_class!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New BaseClass")
    |> assign(:base_class, %BaseClass{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing BaseClasss")
    |> assign(:base_class, nil)
  end

  @impl true
  def handle_info({GameWeb.BaseClassLive.FormComponent, {:saved, base_class}}, socket) do
    {:noreply, stream_insert(socket, :base_classes, base_class)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    base_class = Content.get_base_class!(id)
    {:ok, _} = Content.delete_base_class(base_class)

    {:noreply, stream_delete(socket, :base_classes, base_class)}
  end
end
