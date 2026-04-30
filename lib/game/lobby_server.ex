defmodule Game.LobbyServer do
  use GenServer

  def start_link(id) do
    GenServer.start_link(__MODULE__, id, name: via(id))
  end

  def get_state(id) do
    GenServer.call(via(id), :get_state)
  end

  def join(id, user) do
    GenServer.call(via(id), {:join, user})
  end

  def leave(id, user_id) do
    GenServer.cast(via(id), {:leave, user_id})
  end

  def toggle_ready(id, user_id) do
    GenServer.call(via(id), {:toggle_ready, user_id})
  end

  def select_class(id, user_id, class) do
    GenServer.call(via(id), {:select_class, user_id, class})
  end

  def reset(id) do
    GenServer.cast(via(id), :reset)
  end

  defp via(id), do: {:via, Registry, {Game.LobbyRegistry, id}}

  @impl true
  def init(id) do
    {:ok, %{id: id, players: [], status: :waiting, game_pid: nil}}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:join, user}, _from, %{players: players} = state) do
    cond do
      Enum.any?(players, &(&1.id == user.id)) ->
        {:reply, {:ok, state}, state}

      length(players) >= 2 ->
        {:reply, {:error, :full}, state}

      true ->
        player = %{id: user.id, email: user.email, ready: false, class: nil}
        new_players = players ++ [player]
        new_status = if length(new_players) == 2, do: :ready, else: :waiting
        new_state = %{state | players: new_players, status: new_status}
        broadcast(new_state)
        {:reply, {:ok, new_state}, new_state}
    end
  end

  @impl true
  def handle_call({:toggle_ready, user_id}, _from, state) do
    player = Enum.find(state.players, &(&1.id == user_id))

    if is_nil(player) or is_nil(player.class) do
      {:reply, {:ok, state}, state}
    else
      new_players =
        Enum.map(state.players, fn
          %{id: ^user_id} = p -> %{p | ready: !p.ready}
          p -> p
        end)

      new_state = %{state | players: new_players}
      new_state = maybe_start_game(new_state)
      broadcast(new_state)
      {:reply, {:ok, new_state}, new_state}
    end
  end

  @impl true
  def handle_call({:select_class, user_id, class}, _from, state) do
    new_players =
      Enum.map(state.players, fn
        %{id: ^user_id} = p -> %{p | class: class}
        p -> p
      end)

    new_state = %{state | players: new_players}
    broadcast(new_state)
    {:reply, {:ok, new_state}, new_state}
  end

  @impl true
  def handle_cast({:leave, user_id}, state) do
    new_players = Enum.reject(state.players, &(&1.id == user_id))
    new_status = if length(new_players) == 2, do: :ready, else: :waiting
    new_state = %{state | players: new_players, status: new_status}
    broadcast(new_state)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:reset, state) do
    new_players = Enum.map(state.players, &%{&1 | ready: false})
    new_state = %{state | players: new_players, game_pid: nil}
    broadcast(new_state)
    {:noreply, new_state}
  end

  defp maybe_start_game(%{players: players, game_pid: nil} = state) do
    all_ready = length(players) == 2 and Enum.all?(players, &(&1.ready and not is_nil(&1.class)))

    if all_ready do
      [p1, p2] = players

      combat =
        Game.CombatBuilder.build([
          %{class: p1.class, team: p1.id, position: {0, 0, 0}, id: p1.id},
          %{class: p2.class, team: p2.id, position: {2, -1, -1}, id: p2.id}
        ])

      {:ok, game_pid} = Game.start_link()
      :ok = GenServer.call(game_pid, {:set_state, %{current_view: :combat, combat: combat}})
      %{state | game_pid: game_pid}
    else
      state
    end
  end

  defp maybe_start_game(state), do: state

  defp broadcast(state) do
    Phoenix.PubSub.broadcast(Game.PubSub, "lobby:#{state.id}", {:lobby_updated, state})
  end
end
