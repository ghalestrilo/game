# Feature: Oban Cleanup Job for Inactive Lobbies

## Context

Lobbies are pure in-memory GenServers managed by `Game.LobbySupervisor` (a `DynamicSupervisor`)
and indexed by `Game.LobbyRegistry`. They have no database persistence and no timestamps — once
created they live until the process crashes or the node restarts. There is no automatic timeout.

The action log and telemetry have no lobby-level activity tracking, so the correct approach is to
stamp `last_active_at` directly in `LobbyServer` state and read it from the Oban worker via the
Registry. Oban is not yet a dependency and needs to be added.

---

## Implementation Plan

### 1. Add Oban

**File:** `mix.exs`

```elixir
{:oban, "~> 2.18"}
```

**File:** `config/config.exs`

```elixir
config :game, Oban,
  repo: Game.Repo,
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24},   # prune completed jobs after 24h
    {Oban.Plugins.Cron,
     crontab: [
       {"*/15 * * * *", Game.Workers.LobbyCleanup}   # every 15 minutes
     ]}
  ],
  queues: [default: 10]
```

**File:** `lib/game/application.ex`

Add `{Oban, Application.fetch_env!(:game, Oban)}` to the supervision tree children, after the
Repo and before the PubSub.

**Migration** — Oban needs its own tables:

```bash
mix oban.install   # generates the migration automatically
mix ecto.migrate
```

### 2. Track `last_active_at` in LobbyServer

**File:** `lib/game/lobby_server.ex`

Add `last_active_at: DateTime.utc_now()` to each `init` clause:

```elixir
def init({id, :pvp}) do
  {:ok, %{
    id: id, mode: :pvp, players: [], status: :waiting, game_pid: nil,
    settings: %{boosters: 0, map: nil},
    last_active_at: DateTime.utc_now()
  }}
end

def init({id, mode, build_opts}) when mode in [:campaign, :sandbox] do
  state = %{id: id, mode: mode, players: [], status: :ready, game_pid: nil,
            last_active_at: DateTime.utc_now()}
  {:ok, start_single_player_game(state, build_opts)}
end
```

Update `last_active_at` on every state change. All mutations already funnel through `broadcast/1`,
making it the single right place:

```elixir
defp broadcast(state) do
  state = %{state | last_active_at: DateTime.utc_now()}
  Phoenix.PubSub.broadcast(Game.PubSub, "lobby:#{state.id}", {:lobby_updated, state})
  state
end
```

Each call site does `new_state = %{state | ...}; broadcast(new_state)` and discards the return
value — change those call sites to use the returned state so the updated timestamp is preserved in
the GenServer:

```elixir
# Before (pattern throughout the file):
new_state = %{state | players: new_players}
broadcast(new_state)
{:reply, {:ok, new_state}, new_state}

# After:
new_state = %{state | players: new_players} |> broadcast()
{:reply, {:ok, new_state}, new_state}
```

This requires `broadcast/1` to return the state (it currently returns the PubSub result):

```elixir
defp broadcast(state) do
  state = %{state | last_active_at: DateTime.utc_now()}
  Phoenix.PubSub.broadcast(Game.PubSub, "lobby:#{state.id}", {:lobby_updated, state})
  state   # return state so callers can pipe
end
```

### 3. Expose lobby state via a queryable function

**File:** `lib/game/lobby.ex` (or `lobby_server.ex`)

Add a function to enumerate all live lobby states:

```elixir
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
```

### 4. Oban worker

**New file:** `lib/game/workers/lobby_cleanup.ex`

```elixir
defmodule Game.Workers.LobbyCleanup do
  use Oban.Worker, queue: :default

  require Logger

  # Lobbies idle for longer than this are terminated
  @inactive_after_minutes 30

  @impl Oban.Worker
  def perform(_job) do
    cutoff = DateTime.add(DateTime.utc_now(), -@inactive_after_minutes * 60, :second)

    Game.Lobby.list_all()
    |> Enum.filter(&lobby_inactive?(&1, cutoff))
    |> Enum.each(&terminate_lobby/1)

    :ok
  end

  defp lobby_inactive?(%{last_active_at: last_active_at, game_pid: game_pid}, cutoff) do
    # Never terminate a lobby that has an active game in progress
    is_nil(game_pid) and DateTime.before?(last_active_at, cutoff)
  end

  defp lobby_inactive?(_lobby, _cutoff), do: false

  defp terminate_lobby(%{id: id}) do
    case Registry.lookup(Game.LobbyRegistry, id) do
      [{pid, _}] ->
        DynamicSupervisor.terminate_child(Game.LobbySupervisor, pid)
        Logger.info("Terminated inactive lobby #{id}")

      [] ->
        :ok
    end
  end
end
```

Key decisions:
- **Never kill a lobby with an active game** (`game_pid != nil`) — the game process owns player
  sessions; let it manage its own lifecycle.
- **30-minute idle window** — tunable via the `@inactive_after_minutes` module attribute or a
  config value.
- Errors in individual terminations are isolated; the job returns `:ok` regardless so Oban does
  not retry on partial failures.

---

## Critical Files

| File | Change |
|------|--------|
| `mix.exs` | Add `{:oban, "~> 2.18"}` |
| `config/config.exs` | Configure Oban with Cron plugin (every 15 min) and Pruner |
| `lib/game/application.ex` | Add Oban to supervision tree |
| `priv/repo/migrations/<ts>_add_oban_jobs.exs` | Generated by `mix oban.install` |
| `lib/game/lobby_server.ex` | Add `last_active_at` to init state; update `broadcast/1` to stamp + return state; update callers to use returned state |
| `lib/game/lobby.ex` | Add `list_all/0` to enumerate live lobby states via Registry |
| `lib/game/workers/lobby_cleanup.ex` | New Oban worker |

---

## Verification

1. `mix deps.get && mix ecto.migrate` — confirm Oban tables created.
2. Start the app; create a lobby and let it sit idle. Check `Game.Lobby.list_all()` in IEx —
   confirm `last_active_at` updates when any action is taken in the lobby.
3. Manually enqueue the worker in IEx:
   ```elixir
   %{} |> Game.Workers.LobbyCleanup.new() |> Oban.insert()
   ```
   Lower `@inactive_after_minutes` temporarily to 0 and confirm the idle lobby process is
   terminated.
4. Confirm a lobby with an active `game_pid` is never terminated by the worker.
5. Check Oban job history — confirm the cron fires every 15 minutes and jobs complete with `:ok`.
