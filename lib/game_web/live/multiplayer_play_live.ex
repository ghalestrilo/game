defmodule GameWeb.MultiplayerPlayLive do
  use GameWeb, :live_view

  alias Game.{Combat, Lobby}

  @impl true
  def mount(%{"id" => lobby_id}, _session, socket) do
    if connected?(socket) do
      user = socket.assigns.current_scope.user

      case Lobby.get(lobby_id) do
        {:error, :not_found} ->
          {:ok, push_navigate(socket, to: ~p"/multiplayer")}

        {:ok, %{game_pid: nil}} ->
          {:ok, push_navigate(socket, to: ~p"/multiplayer/#{lobby_id}")}

        {:ok, lobby} ->
          Lobby.subscribe(lobby_id)
          game_state = GenServer.call(lobby.game_pid, :get_state)
          current_player = Enum.find(lobby.players, &(&1.id == user.id))

          {:ok,
           assign(socket,
             lobby_id: lobby_id,
             game_pid: lobby.game_pid,
             game_state: game_state,
             current_player: current_player,
             action_log: []
           )}
      end
    else
      {:ok, assign(socket, lobby_id: nil, game_pid: nil, game_state: nil, current_player: nil, action_log: [])}
    end
  end

  # When lobby is reset (game over), return to lobby
  @impl true
  def handle_info({:lobby_updated, %{game_pid: nil}}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/multiplayer/#{socket.assigns.lobby_id}")}
  end

  def handle_info({:lobby_updated, _}, socket), do: {:noreply, socket}

  def handle_info({:parent_event, event_name, params}, socket) do
    handle_event(event_name, params, socket)
  end

  # Ignore events when it's not this player's turn
  defp my_turn?(socket) do
    current_player = socket.assigns.current_player
    current_turn_player = socket.assigns.game_state.combat.current_turn.player
    current_player && current_turn_player && current_player.id == current_turn_player.id
  end

  @impl true
  def handle_event("pick_card", params, socket) do
    if not my_turn?(socket) do
      {:noreply, put_flash(socket, :error, "It's not your turn")}
    else
      current_turn = socket.assigns.game_state.combat.current_turn
      card = current_turn.player.cards.hand |> Enum.at(String.to_integer(params["card_index"]))

      combat =
        case process_action(socket, {:pick_card, current_turn.player, card}) do
          {:ok, updated_combat} -> updated_combat
          {:error, _} -> socket.assigns.game_state.combat
        end

      updated_game_state = %{socket.assigns.game_state | combat: combat}
      sync_and_maybe_end(socket, updated_game_state)
    end
  end

  @impl true
  def handle_event(
        "interact",
        params,
        %{assigns: %{game_state: %{combat: %{state: :card_selected, current_turn: %{card: card}}}}} = socket
      ) do
    if not my_turn?(socket) do
      {:noreply, put_flash(socket, :error, "It's not your turn")}
    else
      with {:ok, position} <- parse_position(params["target_position"]),
           {:ok, combat} <- process_action(socket, {:play_card, position}) do
        action = "#{socket.assigns.game_state.combat.current_turn.player.name} played #{card.name}"
        updated_game_state = %{socket.assigns.game_state | combat: combat}
        sync_and_maybe_end(socket, updated_game_state, action)
      else
        {:error, reason} -> {:noreply, put_flash(socket, :error, "#{reason}")}
      end
    end
  end

  @impl true
  def handle_event(
        "interact",
        %{"target_position" => target_position},
        %{assigns: %{game_state: %{combat: %{state: :running, current_turn: %{player: player}}}}} = socket
      ) do
    if not my_turn?(socket) do
      {:noreply, put_flash(socket, :error, "It's not your turn")}
    else
      with {:ok, position} <- parse_position(target_position),
           {:ok, combat} <- process_action(socket, {:move, player, position}) do
        action = "#{player.name} moved to #{inspect(position)}"
        updated_game_state = %{socket.assigns.game_state | combat: combat}
        sync_and_maybe_end(socket, updated_game_state, action)
      else
        {:error, reason} -> {:noreply, put_flash(socket, :error, "#{reason}")}
      end
    end
  end

  @impl true
  def handle_event("interact", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("win_match", _params, socket) do
    combat = socket.assigns.game_state.combat
    current_player = combat.current_turn.player

    if is_nil(current_player) do
      {:noreply, put_flash(socket, :error, "No active player")}
    else
      winning_team = current_player.team

      updated_queue = Enum.map(combat.queue, fn char ->
        if char.team != winning_team, do: %{char | dead: true, hp: 0}, else: char
      end)

      updated_combat = %{combat | state: :game_over, queue: updated_queue,
        current_turn: %{combat.current_turn | player: current_player}}

      updated_game_state = %{socket.assigns.game_state | combat: updated_combat}
      sync_and_maybe_end(socket, updated_game_state)
    end
  end

  @impl true
  def handle_event(
        "skip_turn",
        _params,
        %{assigns: %{game_state: %{combat: %{current_turn: %{player: player}}}}} = socket
      ) do
    if not my_turn?(socket) do
      {:noreply, put_flash(socket, :error, "It's not your turn")}
    else
      with {:ok, combat} <- process_action(socket, {:skip_turn, player}) do
        action = "#{player.name} skipped their turn"
        updated_game_state = %{socket.assigns.game_state | combat: combat}
        sync_and_maybe_end(socket, updated_game_state, action)
      else
        {:error, reason} -> {:noreply, put_flash(socket, :error, "#{reason}")}
      end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="campaign-play">
      <%= if @game_state && Map.get(@game_state, :current_view) == :combat do %>
        <.live_component
          module={GameWeb.CombatLive}
          id="combat"
          game_state={@game_state}
          action_log={@action_log}
          modal={nil}
        />
      <% else %>
        <div class="flex items-center justify-center h-screen">
          <p class="text-xl">Loading game...</p>
        </div>
      <% end %>
    </div>
    """
  end

  defp process_action(socket, action) do
    Combat.process_action(socket.assigns.game_state.combat, action)
  end

  defp parse_position(str) do
    case str |> String.split("_") |> Enum.map(&String.to_integer/1) do
      [q, r, s] -> {:ok, {q, r, s}}
      _ -> {:error, "Invalid position"}
    end
  end

  # Syncs the shared GenServer after every action so both players see the update,
  # and triggers Lobby.reset when combat ends (redirecting both sessions to the lobby).
  defp sync_and_maybe_end(socket, game_state, action \\ nil) do
    :ok = GenServer.call(socket.assigns.game_pid, {:set_state, game_state})

    log =
      if action,
        do: [action | socket.assigns.action_log],
        else: socket.assigns.action_log

    socket = assign(socket, game_state: game_state, action_log: log)

    if game_state.combat.state == :game_over do
      Lobby.reset(socket.assigns.lobby_id)
    end

    {:noreply, socket}
  end
end
