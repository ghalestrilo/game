defmodule GameWeb.LobbyLive do
  use GameWeb, :live_view

  alias Game.{Content, Lobby}

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
              base_classes = Content.list_playable_classes()

              {:ok,
               assign(socket,
                 lobby: lobby_state,
                 lobby_id: id,
                 base_classes: base_classes,
                 current_user_id: user.id
               )}

            {:error, :full} ->
              {:ok,
               socket
               |> put_flash(:error, "Lobby is full.")
               |> push_navigate(to: ~p"/multiplayer")}
          end
      end
    else
      {:ok, assign(socket, lobby: nil, lobby_id: id, base_classes: [], current_user_id: nil)}
    end
  end

  @impl true
  def handle_event("select_class", %{"class" => class}, socket) do
    user = socket.assigns.current_scope.user

    case Lobby.select_class(socket.assigns.lobby_id, user.id, class) do
      {:ok, lobby_state} -> {:noreply, assign(socket, lobby: lobby_state)}
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_team", %{"team" => team}, socket) do
    user = socket.assigns.current_scope.user

    case Lobby.select_team(socket.assigns.lobby_id, user.id, team) do
      {:ok, lobby_state} -> {:noreply, assign(socket, lobby: lobby_state)}
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_ready", _params, socket) do
    user = socket.assigns.current_scope.user

    case Lobby.toggle_ready(socket.assigns.lobby_id, user.id) do
      {:ok, lobby_state} -> {:noreply, assign(socket, lobby: lobby_state)}
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:lobby_updated, %{game_pid: game_pid, id: id} = lobby_state}, socket)
      when not is_nil(game_pid) do
    {:noreply,
     socket
     |> assign(lobby: lobby_state)
     |> push_navigate(to: ~p"/multiplayer/#{id}/play")}
  end

  def handle_info({:lobby_updated, lobby_state}, socket) do
    {:noreply, assign(socket, lobby: lobby_state)}
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
              {player.email}
              <span>Team {player.team}</span>
              <%= if player.class do %>
                <span>{player.class}</span>
              <% end %>
              <%= if player.ready do %>
                <span>ready</span>
              <% end %>
            </li>
          <% end %>
        </ul>
        <% my_player = @lobby.players |> Enum.find(&(&1.id == @current_user_id)) %>
        <% my_class = my_player && my_player.class %>
        <% my_team = my_player && my_player.team %>
        <form phx-change="select_class">
          <select name="class">
            <option value="" selected={is_nil(my_class)}>Pick a class</option>
            <%= for bc <- @base_classes do %>
              <option value={bc.class} selected={my_class == bc.class}>{bc.class}</option>
            <% end %>
          </select>
        </form>
        <form phx-change="select_team">
          <select name="team">
              <%= for index <- 1..8 do %>
                <option value={index} selected={my_player.team == index}>Team {index}</option>
              <% end %>
            </select>
        </form>
        <button
          phx-click="toggle_ready"
          disabled={is_nil(my_class)}
          class="px-4 py-2 rounded-2 bg-primary disabled:opacity-50"
        >
          Ready
        </button>
        <%= if @lobby.status == :ready do %>
          <p>Players connected. Game starting soon...</p>
        <% else %>
          <p>Waiting for players...</p>
        <% end %>
      <% else %>
        <p>Connecting...</p>
      <% end %>
    </div>
    """
  end
end
