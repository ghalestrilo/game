defmodule GameWeb.LobbyLive do
  use GameWeb, :live_view

  alias Game.{Content, Lobby, Maps}

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

              db_maps = Maps.list_db()

              map_options =
                [{"No map", ""}] ++
                  Enum.map(db_maps, &{&1.display_name, &1.slug})

              {:ok,
               assign(socket,
                 lobby: lobby_state,
                 lobby_id: id,
                 base_classes: base_classes,
                 map_options: map_options,
                 current_user_id: user.id,
                 invite_feedback: nil
               )}

            {:error, :full} ->
              {:ok,
               socket
               |> put_flash(:error, "Lobby is full.")
               |> push_navigate(to: ~p"/multiplayer")}
          end
      end
    else
      {:ok,
       assign(socket,
         lobby: nil,
         lobby_id: id,
         base_classes: [],
         map_options: [],
         current_user_id: nil,
         invite_feedback: nil
       )}
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
  def handle_event("set_name", %{"name" => name}, socket) do
    user = socket.assigns.current_scope.user

    case Lobby.set_name(socket.assigns.lobby_id, user.id, name) do
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
  def handle_event("set_booster_size", %{"booster_size" => value}, socket) do
    size = value |> String.to_integer() |> max(1)

    case Lobby.set_setting(socket.assigns.lobby_id, :booster_size, size) do
      {:ok, lobby_state} -> {:noreply, assign(socket, lobby: lobby_state)}
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("set_deck_picks", %{"deck_picks" => value}, socket) do
    picks = value |> String.to_integer() |> max(1)

    case Lobby.set_setting(socket.assigns.lobby_id, :deck_picks, picks) do
      {:ok, lobby_state} -> {:noreply, assign(socket, lobby: lobby_state)}
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("set_render_3d", params, socket) do
    render_3d = Map.has_key?(params, "render_3d")

    case Lobby.set_setting(socket.assigns.lobby_id, :render_3d, render_3d) do
      {:ok, lobby_state} -> {:noreply, assign(socket, lobby: lobby_state)}
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("set_map", %{"map" => slug}, socket) do
    map_slug = if slug == "", do: nil, else: slug

    case Lobby.set_setting(socket.assigns.lobby_id, :map, map_slug) do
      {:ok, lobby_state} -> {:noreply, assign(socket, lobby: lobby_state)}
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("send_invite", %{"email" => email}, socket) do
    from = socket.assigns.current_scope.user.email
    Lobby.broadcast_invite(email, from, socket.assigns.lobby_id)
    {:noreply, assign(socket, invite_feedback: "Invite sent to #{email}")}
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
    render_3d = Map.get(lobby_state.settings || %{}, :render_3d, true)

    play_path =
      if render_3d, do: ~p"/multiplayer/#{id}/play?3d=true", else: ~p"/multiplayer/#{id}/play"

    {:noreply,
     socket
     |> assign(lobby: lobby_state)
     |> push_navigate(to: play_path)}
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
          <div class="list flex flex-col gap-4 mt-4">
            <% my_player = @lobby.players |> Enum.find(&(&1.id == @current_user_id)) %>
            <% my_class = my_player && my_player.class %>
            <% my_team = my_player && my_player.team %>
            <fieldset class="fieldset w-full bg-base-200 border-base-300 rounded-box border p-4">
              <legend class="fieldset-legend">My Character</legend>
              <form class="join w-full" phx-change="select_class">
                <label class="join-item btn btn-neutral no-animation flex-none">Class</label>
                <select name="class" class="join-item select select-bordered flex-1">
                  <option value="" selected={is_nil(my_class)}>Pick a class</option>
                  <%= for bc <- @base_classes do %>
                    <option value={bc.class} selected={my_class == bc.class}>{bc.class}</option>
                  <% end %>
                </select>
              </form>
              <form class="join w-full" phx-change="select_team">
                <label class="join-item btn btn-neutral no-animation flex-none">Team</label>
                <select name="team" class="join-item select select-bordered flex-1">
                  <option value={nil} selected={is_nil(my_player.team)}>Pick a team</option>
                  <%= for index <- 1..8 do %>
                    <option value={index} selected={my_player.team == to_string(index)}>
                      Team {index}
                    </option>
                  <% end %>
                </select>
              </form>
              <% my_name = my_player && my_player.name %>
              <form class="join w-full" phx-change="set_name">
                <label class="join-item btn btn-neutral no-animation flex-none">Display</label>
                <input
                  type="text"
                  name="name"
                  value={my_name || ""}
                  placeholder={@current_scope.user.email}
                  class="join-item input input-bordered flex-1"
                />
              </form>
            </fieldset>
            <% is_host = hd(@lobby.players).id == @current_user_id %>
            <% boosters = get_in(@lobby, [:settings, :boosters]) || 0 %>
            <% booster_size = get_in(@lobby, [:settings, :booster_size]) || 5 %>
            <% deck_picks = get_in(@lobby, [:settings, :deck_picks]) || 1 %>
            <fieldset class="fieldset w-full bg-base-200 border-base-300 rounded-box border p-4">
              <legend class="fieldset-legend">Lobby Settings</legend>
              <div class="flex w-full items-center justify-between">
                <label class="fieldset-label">Booster packs at start</label>
                <%= if is_host do %>
                  <form phx-change="set_boosters">
                    <input
                      type="number"
                      name="boosters"
                      value={boosters}
                      min="0"
                      max="10"
                      class="input input-lg input-bordered w-20"
                    />
                  </form>
                <% else %>
                  <span class="badge badge-lg">{boosters}</span>
                <% end %>
              </div>
              <div class="flex w-full items-center justify-between">
                <label class="fieldset-label">Cards per booster</label>
                <%= if is_host do %>
                  <form phx-change="set_booster_size">
                    <input
                      type="number"
                      name="booster_size"
                      value={booster_size}
                      min="1"
                      max="20"
                      class="input input-lg input-bordered w-20"
                    />
                  </form>
                <% else %>
                  <span class="badge badge-lg">{booster_size}</span>
                <% end %>
              </div>
              <div class="flex w-full items-center justify-between">
                <label class="fieldset-label">Picks per booster</label>
                <%= if is_host do %>
                  <form phx-change="set_deck_picks">
                    <input
                      type="number"
                      name="deck_picks"
                      value={deck_picks}
                      min="1"
                      max="20"
                      class="input input-lg input-bordered w-20"
                    />
                  </form>
                <% else %>
                  <span class="badge badge-lg">{deck_picks}</span>
                <% end %>
              </div>
              <% selected_map = get_in(@lobby, [:settings, :map]) || "" %>
              <div class="flex w-full items-center justify-between">
                <label class="fieldset-label">Map</label>
                <%= if is_host do %>
                  <form phx-change="set_map">
                    <select name="map" class="select select-bordered">
                      <%= for {label, value} <- @map_options do %>
                        <option value={value} selected={value == selected_map}>{label}</option>
                      <% end %>
                    </select>
                  </form>
                <% else %>
                  <span class="badge badge-lg">
                    {if selected_map == "", do: "None", else: selected_map}
                  </span>
                <% end %>
              </div>
              <% render_3d = Map.get(@lobby.settings || %{}, :render_3d, true) %>
              <div class="flex w-full items-center justify-between">
                <label class="fieldset-label">3D renderer</label>
                <%= if is_host do %>
                  <form phx-change="set_render_3d">
                    <input type="checkbox" name="render_3d" class="checkbox" checked={render_3d} />
                  </form>
                <% else %>
                  <span class="badge badge-lg">{if render_3d, do: "On", else: "Off"}</span>
                <% end %>
              </div>
              <button
                phx-click="toggle_ready"
                disabled={is_nil(my_class)}
                class="btn btn-primary w-full"
              >
                Ready
              </button>
              <button class="btn btn-secondary w-full" phx-click={show_modal("invite-modal")}>
                <.icon name="hero-user-plus-solid" /> Invite Player
              </button>
              <%= if @lobby.status == :ready do %>
                <p>Players connected. Game starting soon...</p>
              <% else %>
                <p>Waiting for players...</p>
              <% end %>
            </fieldset>
          </div>
          <ul class="grid grid-cols-2 xl:grid-cols-3 gap-8 p-4">
            <%= for {team, players} <- Enum.group_by(@lobby.players, & &1.team) do %>
              <li class={[
                "indicator flex flex-col items-st w-full border-2 rounded-xl p-4",
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
                    class={[
                      "list-row indicator list-col-wrap w-full text-lg rounded",
                      if(player.ready, do: "bg-success/30")
                    ]}
                  >
                    <p class="list-col-grow">{player.name || player.email}</p>
                    <%= if player.class do %>
                      <span class="badge badge-soft badge-lg badge-warning min-w-fit">
                        {player.class}
                      </span>
                    <% end %>
                    <.icon
                      :if={player.ready}
                      name="hero-check-circle-mini"
                      class="indicator-item indicator-top indicator-end bg-success rounded-full w-8 h-8"
                    />
                  </li>
                </ul>
              </li>
            <% end %>
          </ul>
        </div>
      <% else %>
        <p>Connecting...</p>
      <% end %>

      <.modal id="invite-modal">
        <h2 class="text-2xl font-bold mb-6">Invite a Player</h2>

        <p class="fieldset-label mb-2">Share lobby link</p>
        <div class="join w-full mb-6">
          <input
            id="lobby-link-input"
            type="text"
            readonly
            value={url(~p"/multiplayer/#{@lobby_id}")}
            class="join-item input input-bordered flex-1"
          />
          <button
            class="join-item btn btn-neutral"
            phx-hook="CopyToClipboard"
            data-target="lobby-link-input"
            id="copy-lobby-link-btn"
          >
            <.icon name="hero-clipboard-solid" /> Copy
          </button>
        </div>

        <p class="fieldset-label mb-2">Send invite notification</p>
        <form phx-submit="send_invite" class="join w-full">
          <input
            type="email"
            name="email"
            placeholder="player@example.com"
            required
            class="join-item input input-bordered flex-1"
          />
          <button type="submit" class="join-item btn btn-primary">
            <.icon name="hero-paper-airplane-solid" /> Send Invite
          </button>
        </form>
        <%= if @invite_feedback do %>
          <p class="mt-3 text-sm text-success">{@invite_feedback}</p>
        <% end %>
      </.modal>
    </div>
    """
  end
end
