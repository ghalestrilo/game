defmodule Game.Lobby do
  alias Game.LobbyServer

  def create() do
    id = Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
    {:ok, _pid} = DynamicSupervisor.start_child(Game.LobbySupervisor, {LobbyServer, {id, :pvp}})
    {:ok, id}
  end

  @doc """
  Creates a single-player lobby for :campaign or :sandbox mode.

  build_opts must include:
    - combatants: list of combatant configs passed to CombatBuilder.build/1
    - extra_state: (optional) map merged into the initial game state (e.g. campaign data)
  """
  def create_single_player(mode, build_opts) when mode in [:campaign, :sandbox] do
    id = Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)

    {:ok, _pid} =
      DynamicSupervisor.start_child(Game.LobbySupervisor, {LobbyServer, {id, mode, build_opts}})

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

  def select_team(id, user_id, team) do
    case Registry.lookup(Game.LobbyRegistry, id) do
      [{_pid, _}] -> LobbyServer.select_team(id, user_id, team)
      [] -> {:error, :not_found}
    end
  end

  def set_name(id, user_id, name) do
    case Registry.lookup(Game.LobbyRegistry, id) do
      [{_pid, _}] -> LobbyServer.set_name(id, user_id, name)
      [] -> {:error, :not_found}
    end
  end

  def toggle_ready(id, user_id) do
    case Registry.lookup(Game.LobbyRegistry, id) do
      [{_pid, _}] -> LobbyServer.toggle_ready(id, user_id)
      [] -> {:error, :not_found}
    end
  end

  def set_setting(id, key, value) do
    case Registry.lookup(Game.LobbyRegistry, id) do
      [{_pid, _}] -> LobbyServer.set_setting(id, key, value)
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

  def list_all() do
    Game.LobbyRegistry
    |> Registry.select([{{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}])
    |> Enum.flat_map(fn {_id, pid} ->
      case GenServer.call(pid, :get_state, 5_000) do
        state when is_map(state) -> [state]
        _ -> []
      end
    end)
  rescue
    _ -> []
  end

  def subscribe(id) do
    Phoenix.PubSub.subscribe(Game.PubSub, "lobby:#{id}")
  end

  def subscribe_invites(user_email) do
    Phoenix.PubSub.subscribe(Game.PubSub, "invites:#{user_email}")
  end

  def broadcast_invite(to_email, from_email, lobby_id) do
    Phoenix.PubSub.broadcast(
      Game.PubSub,
      "invites:#{to_email}",
      {:invited, %{from: from_email, lobby_id: lobby_id}}
    )
  end
end
