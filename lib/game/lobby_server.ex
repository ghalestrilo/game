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

  defp via(id), do: {:via, Registry, {Game.LobbyRegistry, id}}

  @impl true
  def init(id) do
    {:ok, %{id: id, players: [], status: :waiting}}
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
        player = %{id: user.id, email: user.email}
        new_players = players ++ [player]
        new_status = if length(new_players) == 2, do: :ready, else: :waiting
        new_state = %{state | players: new_players, status: new_status}
        broadcast(new_state)
        {:reply, {:ok, new_state}, new_state}
    end
  end

  @impl true
  def handle_cast({:leave, user_id}, state) do
    new_players = Enum.reject(state.players, &(&1.id == user_id))
    new_status = if length(new_players) == 2, do: :ready, else: :waiting
    new_state = %{state | players: new_players, status: new_status}
    broadcast(new_state)
    {:noreply, new_state}
  end

  defp broadcast(state) do
    Phoenix.PubSub.broadcast(Game.PubSub, "lobby:#{state.id}", {:lobby_updated, state})
  end
end
