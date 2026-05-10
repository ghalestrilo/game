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
  def handle_event("set_boosters", %{"boosters" => value}, socket) do
    count = value |> String.to_integer() |> max(0)

    case Lobby.set_setting(socket.assigns.lobby_id, :boosters, count) do
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
    <div class="w-full max-w-screen h-screen justify-center items-center gap-4">
      <h1 class="text-4xl font-bold">Multiplayer Lobby</h1>
      <%= if @lobby do %>
        <div class="grid grid-cols-[320px_1fr] gap-8">
          <div class="flex flex-col gap-4 mt-4">
          <% my_player = @lobby.players |> Enum.find(&(&1.id == @current_user_id)) %>
          <% my_class = my_player && my_player.class %>
          <% my_team = my_player && my_player.team %>

            <div class="flex flex-col gap-2">
            <h2 class="text-xl font-semibold">My Character</h2>
            <form phx-change="select_class">
              <span class="flex flex-1 justify-between">
                <label>Class</label>
                <select name="class">
                  <option value="" selected={is_nil(my_class)}>Pick a class</option>
                  <%= for bc <- @base_classes do %>
                    <option value={bc.class} selected={my_class == bc.class}>{bc.class}</option>
                  <% end %>
                </select>
              </span>
            </form>
            <form phx-change="select_team">
              <span class="flex flex-1 justify-between">
                <label>Team</label>
                <select name="team">
                  <%= for index <- 1..8 do %>
                    <option value={index} selected={my_player.team == index}>Team {index}</option>
                  <% end %>
                </select>
              </span>
            </form>
            </div>
            <% is_host = hd(@lobby.players).id == @current_user_id %>
            <% boosters = get_in(@lobby, [:settings, :boosters]) || 0 %>
            <ul class="flex flex-col items-start gap-2">
              <h2 class="text-xl font-semibold">Lobby Settings</h2>
              <span class="flex w-full justify-between">
                <label class="text-sm font-semibold">Booster packs at start:</label>
                <%= if is_host do %>
                  <form phx-change="set_boosters">
                    <input
                      type="number"
                      name="boosters"
                      value={boosters}
                      min="0"
                      max="10"
                      class="input input-sm input-bordered w-20"
                    />
                  </form>
                <% else %>
                  <span class="badge badge-lg">{boosters}</span>
                <% end %>
              </span>
              <button
                phx-click="toggle_ready"
                disabled={is_nil(my_class)}
                class="btn btn-primary w-full"
              >
                Ready
              </button>
              <%= if @lobby.status == :ready do %>
                <p>Players connected. Game starting soon...</p>
              <% else %>
                <p>Waiting for players...</p>
              <% end %>
            </ul>
          </div>
          <ul class="grid grid-cols-2 xl:grid-cols-3 gap-8 p-4">
            <%= for {team, players} <- Enum.group_by(@lobby.players, & &1.team) do %>
              <li class={[
                "indicator flex flex-col items-st w-full border-2 rounded-xl p-2",
                GameWeb.Theme.team_ring_class(team)
              ]}>
                <span class={[
                  "indicator-item indicator-start indicator-top ml-4 badge",
                  GameWeb.Theme.team_bg_class(team)
                ]}>
                  Team {team}
                </span>
                <ul class="list">
                  <li
                    :for={player <- players}
                    class={["list-row  list-col-wrap  w-full text-lg rounded",
                    (if player.ready, do: "bg-success/30")
                    ]}
                  >
                    <p class="list-col-grow">{player.email}</p>
                    <%= if player.class do %>
                      <span class="badge badge-soft badge-lg badge-warning min-w-fit">{player.class}</span>
                    <% end %>
                    <%= if player.ready do %>
                      <span>ready</span>
                    <% end %>
                  </li>
                </ul>
              </li>
            <% end %>
          </ul>
        </div>
      <% else %>
        <p>Connecting...</p>
      <% end %>
    </div>
    """
  end
end
