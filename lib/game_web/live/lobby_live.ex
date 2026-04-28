defmodule GameWeb.LobbyLive do
  use GameWeb, :live_view

  alias Game.Lobby

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      user = socket.assigns.current_scope.user

      case Lobby.get(id) do
        {:error, :not_found} ->
          {:ok,
           socket
           |> put_flash(:error, "Lobby not found.")
           |> push_navigate(to: ~p"/multiplayer")}

        {:ok, _lobby} ->
          Lobby.subscribe(id)

          case Lobby.join(id, user) do
            {:ok, lobby_state} ->
              {:ok, assign(socket, lobby: lobby_state, lobby_id: id)}

            {:error, :full} ->
              {:ok,
               socket
               |> put_flash(:error, "Lobby is full.")
               |> push_navigate(to: ~p"/multiplayer")}
          end
      end
    else
      {:ok, assign(socket, lobby: nil, lobby_id: id)}
    end
  end

  @impl true
  def handle_event("toggle_ready", _params, socket) do
    user = socket.assigns.current_scope.user
    Lobby.toggle_ready(socket.assigns.lobby_id, user.id)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:lobby_updated, lobby_state}, socket) do
    {:noreply, assign(socket, lobby: lobby_state)}
  end

  @impl true
  def terminate(_reason, socket) do
    with %{lobby_id: id, current_scope: %{user: user}} when not is_nil(user) <- socket.assigns do
      Lobby.leave(id, user.id)
    end

    :ok
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-screen justify-center items-center gap-4">
      <h1 class="text-2xl font-bold">Lobby</h1>
      <%= if @lobby do %>
        <ul class="flex flex-col gap-2">
          <%= for player <- @lobby.players do %>
            <li class="px-4 py-2 bg-secondary rounded flex gap-2 items-center">
              <%= player.email %>
              <%= if player.ready do %>
                <span>ready</span>
              <% end %>
            </li>
          <% end %>
        </ul>
        <button phx-click="toggle_ready" class="px-4 py-2 rounded-2 bg-primary text-primary">
          Ready
        </button>
        <%= if @lobby.status == :ready do %>
          <p>Both players connected. Game starting soon...</p>
        <% else %>
          <p>Waiting for opponent...</p>
        <% end %>
      <% else %>
        <p>Connecting...</p>
      <% end %>
    </div>
    """
  end
end
