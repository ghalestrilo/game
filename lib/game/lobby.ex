defmodule Game.Lobby do
  alias Game.LobbyServer

  def create() do
    id = Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
    {:ok, _pid} = DynamicSupervisor.start_child(Game.LobbySupervisor, {LobbyServer, id})
    {:ok, id}
  end

  def get(id) do
    case Registry.lookup(Game.LobbyRegistry, id) do
      [{_pid, _}] -> {:ok, LobbyServer.get_state(id)}
      [] -> {:error, :not_found}
    end
  end

  def join(id, user) do
    case Registry.lookup(Game.LobbyRegistry, id) do
      [{_pid, _}] -> LobbyServer.join(id, user)
      [] -> {:error, :not_found}
    end
  end

  def select_class(id, user_id, class) do
    case Registry.lookup(Game.LobbyRegistry, id) do
      [{_pid, _}] -> LobbyServer.select_class(id, user_id, class)
      [] -> {:error, :not_found}
    end
  end

  def toggle_ready(id, user_id) do
    case Registry.lookup(Game.LobbyRegistry, id) do
      [{_pid, _}] -> LobbyServer.toggle_ready(id, user_id)
      [] -> {:error, :not_found}
    end
  end

  def reset(id) do
    case Registry.lookup(Game.LobbyRegistry, id) do
      [{_pid, _}] -> LobbyServer.reset(id)
      [] -> :ok
    end
  end

  def leave(id, user_id) do
    case Registry.lookup(Game.LobbyRegistry, id) do
      [{_pid, _}] -> LobbyServer.leave(id, user_id)
      [] -> :ok
    end
  end

  def subscribe(id) do
    Phoenix.PubSub.subscribe(Game.PubSub, "lobby:#{id}")
  end
end
