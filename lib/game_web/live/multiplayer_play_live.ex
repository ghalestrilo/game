defmodule GameWeb.MultiplayerPlayLive do
  use GameWeb, :live_view

  alias Game.Lobby

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
          Game.subscribe(lobby.game_pid)

          game_state = Game.get_state(lobby.game_pid)
          current_player = lobby.players |> Enum.find(&(&1.id == user.id)) |> Map.put(:team, user.id)

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
      {:ok,
       assign(socket,
         lobby_id: nil,
         game_pid: nil,
         game_state: nil,
         current_player: nil,
         action_log: []
       )}
    end
  end

  # Shared game state update — both sessions receive this
  @impl true
  def handle_info({:game_updated, game_state}, socket) do
    {:noreply, assign(socket, game_state: game_state)}
  end

  # Lobby reset (game over) — return to lobby
  def handle_info({:lobby_updated, %{game_pid: nil}}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/multiplayer/#{socket.assigns.lobby_id}")}
  end

  def handle_info({:lobby_updated, _}, socket), do: {:noreply, socket}

  def handle_info({:parent_event, event_name, params}, socket) do
    handle_event(event_name, params, socket)
  end

  defp my_turn?(socket) do
    me = socket.assigns.current_player
    current = socket.assigns.game_state.combat.current_turn.player
    me && current && me.id == current.id
  end

  @impl true
  def handle_event("pick_card", params, socket) do
    if not my_turn?(socket) do
      {:noreply, put_flash(socket, :error, "It's not your turn")}
    else
      current_turn = socket.assigns.game_state.combat.current_turn
      card = Enum.at(current_turn.player.cards.hand, String.to_integer(params["card_index"]))
      Game.process_action(socket.assigns.game_pid, {:pick_card, current_turn.player, card})
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event(
        "interact",
        %{"target_character_id" => character_id},
        %{
          assigns: %{game_state: %{combat: %{state: :card_selected} = combat}}
        } = socket
      ) do
    if not my_turn?(socket) do
      {:noreply, put_flash(socket, :error, "It's not your turn")}
    else
      character =
        Game.CombatState.get_current_queue(combat)
        |> Enum.find(&(to_string(&1.id) == character_id))

      if character do
        Game.process_action(socket.assigns.game_pid, {:play_card_on_character, character})
        {:noreply, socket}
      else
        {:noreply, put_flash(socket, :error, "Target not found")}
      end
    end
  end

  @impl true
  def handle_event(
        "interact",
        %{"target_position" => target_position},
        %{
          assigns: %{game_state: %{combat: %{state: :card_selected}}}
        } = socket
      ) do
    if not my_turn?(socket) do
      {:noreply, put_flash(socket, :error, "It's not your turn")}
    else
      with {:ok, position} <- parse_position(target_position) do
        Game.process_action(socket.assigns.game_pid, {:play_card, position})
        {:noreply, socket}
      else
        {:error, reason} -> {:noreply, put_flash(socket, :error, "#{reason}")}
      end
    end
  end

  @impl true
  def handle_event(
        "interact",
        %{"target_position" => target_position},
        %{assigns: %{game_state: %{combat: %{state: :running, current_turn: %{player: player}}}}} =
          socket
      ) do
    if not my_turn?(socket) do
      {:noreply, put_flash(socket, :error, "It's not your turn")}
    else
      with {:ok, position} <- parse_position(target_position) do
        Game.process_action(socket.assigns.game_pid, {:move, player, position})
        {:noreply, socket}
      else
        {:error, reason} -> {:noreply, put_flash(socket, :error, "#{reason}")}
      end
    end
  end

  @impl true
  def handle_event("interact", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event(
        "skip_turn",
        _params,
        %{assigns: %{game_state: %{combat: %{current_turn: %{player: player}}}}} = socket
      ) do
    if not my_turn?(socket) do
      {:noreply, put_flash(socket, :error, "It's not your turn")}
    else
      Game.process_action(socket.assigns.game_pid, {:skip_turn, player})
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("win_match", _params, socket) do
    combat = socket.assigns.game_state.combat
    current_player = combat.current_turn.player

    if is_nil(current_player) do
      {:noreply, put_flash(socket, :error, "No active player")}
    else
      winning_team = current_player.team

      updated_queue =
        Enum.map(combat.queue, fn char ->
          if char.team != winning_team, do: %{char | dead: true, hp: 0}, else: char
        end)

      updated_combat = %{combat | state: :game_over, queue: updated_queue}
      new_state = %{socket.assigns.game_state | combat: updated_combat}

      GenServer.call(socket.assigns.game_pid, {:set_state, new_state})
      Lobby.reset(socket.assigns.lobby_id)
      {:noreply, socket}
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
          current_player={@current_player}
        />
      <% else %>
        <div class="flex items-center justify-center h-screen">
          <p class="text-xl">Loading game...</p>
        </div>
      <% end %>
    </div>
    """
  end

  defp parse_position(str) do
    case str |> String.split("_") |> Enum.map(&String.to_integer/1) do
      [q, r, s] -> {:ok, {q, r, s}}
      _ -> {:error, "Invalid position"}
    end
  end
end
