defmodule Game.LobbyServer do
  use GenServer

  def start_link({id, :pvp}) do
    GenServer.start_link(__MODULE__, {id, :pvp}, name: via(id))
  end

  def start_link({id, mode, build_opts}) when mode in [:campaign, :sandbox] do
    GenServer.start_link(__MODULE__, {id, mode, build_opts}, name: via(id))
  end

  # Keep backward compat for PvP lobbies started with just an id
  def start_link(id) when is_binary(id) do
    GenServer.start_link(__MODULE__, {id, :pvp}, name: via(id))
  end

  def get_state(id) do
    GenServer.call(via(id), :get_state)
  end

  def join(id, user) do
    GenServer.call(via(id), {:join, user})
  end

  def leave(id, user_id) do
    GenServer.call(via(id), {:leave, user_id})
  end

  def toggle_ready(id, user_id) do
    GenServer.call(via(id), {:toggle_ready, user_id})
  end

  def select_class(id, user_id, class) do
    GenServer.call(via(id), {:select_class, user_id, class})
  end

  def select_team(id, user_id, team) do
    GenServer.call(via(id), {:select_team, user_id, team})
  end

  def set_setting(id, key, value) do
    GenServer.call(via(id), {:set_setting, key, value})
  end

  def reset(id) do
    GenServer.cast(via(id), :reset)
  end

  defp via(id), do: {:via, Registry, {Game.LobbyRegistry, id}}

  @impl true
  def init({id, :pvp}) do
    {:ok, %{id: id, mode: :pvp, players: [], status: :waiting, game_pid: nil, settings: %{boosters: 0}}}
  end

  def init({id, mode, build_opts}) when mode in [:campaign, :sandbox] do
    state = %{id: id, mode: mode, players: [], status: :ready, game_pid: nil}
    {:ok, start_single_player_game(state, build_opts)}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @max_players 8
  @min_players 2

  @impl true
  def handle_call({:join, user}, _from, %{players: players} = state) do
    cond do
      Enum.any?(players, &(&1.id == user.id)) ->
        {:reply, {:ok, state}, state}

      length(players) >= @max_players ->
        {:reply, {:error, :full}, state}

      true ->
        team = "#{length(players) + 1}"
        player = %{id: user.id, email: user.email, ready: false, class: nil, team: team}
        new_players = players ++ [player]
        new_status = if length(new_players) >= @min_players, do: :ready, else: :waiting
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
  def handle_call({:select_team, user_id, team}, _from, state) do
    new_players =
      Enum.map(state.players, fn
        %{id: ^user_id} = p -> %{p | team: team}
        p -> p
      end)

    new_state = %{state | players: new_players}
    broadcast(new_state)
    {:reply, {:ok, new_state}, new_state}
  end

  @impl true
  def handle_call({:set_setting, key, value}, _from, state) do
    new_state = %{state | settings: Map.put(state.settings, key, value)}
    broadcast(new_state)
    {:reply, {:ok, new_state}, new_state}
  end

  @impl true
  def handle_call({:leave, user_id}, _from, state) do
    new_players = Enum.reject(state.players, &(&1.id == user_id))
    new_status = if length(new_players) >= @min_players, do: :ready, else: :waiting
    new_state = %{state | players: new_players, status: new_status}
    broadcast(new_state)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_cast(:reset, state) do
    if state.game_pid, do: GenServer.stop(state.game_pid, :normal)
    new_players = Enum.map(state.players, &%{&1 | ready: false})
    new_state = %{state | players: new_players, game_pid: nil}
    broadcast(new_state)
    {:noreply, new_state}
  end

  # Spread players evenly around a ring of radius 3 in axial hex coords.
  # Pairs opposite each other: index i gets angle i * (2π / n).
  defp starting_positions(n) do
    radius = 3

    Enum.map(0..(n - 1), fn i ->
      angle = 2 * :math.pi() * i / n
      q = round(radius * :math.cos(angle))
      r = round(radius * :math.sin(angle))
      {q, r, -q - r}
    end)
  end

  defp maybe_start_game(%{players: players, game_pid: nil} = state) do
    all_ready =
      length(players) >= @min_players and
        Enum.all?(players, &(&1.ready and not is_nil(&1.class)))

    teams_ok = players |> Enum.map(& &1.team) |> Enum.uniq() |> length() >= 2

    if all_ready and teams_ok do
      positions = starting_positions(length(players))

      specs =
        players
        |> Enum.zip(positions)
        |> Enum.map(fn {p, pos} ->
          %{class: p.class, team: p.team, position: pos, id: p.id}
        end)

      combat = Game.CombatBuilder.build(specs)
      {:ok, game_pid} = Game.start_link()
      boosters = get_in(state, [:settings, :boosters]) || 0
      initial_view = if boosters > 0, do: :booster, else: :combat

      # Per-player booster state: each player gets their own independent pack countdown and card list.
      player_ids = Enum.map(players, & &1.id)

      booster_state =
        Map.new(player_ids, fn id ->
          cards = if boosters > 0, do: Game.generate_booster_cards(5), else: []
          {id, %{remaining: boosters, cards: cards}}
        end)

      :ok =
        GenServer.call(game_pid, {
          :set_state,
          %{
            current_view: initial_view,
            combat: combat,
            settings: state.settings,
            booster_state: booster_state
          }
        })

      %{state | game_pid: game_pid}
    else
      state
    end
  end

  defp maybe_start_game(state), do: state

  defp start_single_player_game(state, build_opts) do
    {:ok, game_pid} = Game.start_link()
    combat = Game.CombatBuilder.build(build_opts.combatants)

    game_state =
      Map.merge(%{current_view: :combat, combat: combat}, build_opts[:extra_state] || %{})

    :ok = GenServer.call(game_pid, {:set_state, game_state})

    %{state | game_pid: game_pid}
  end

  defp broadcast(state) do
    Phoenix.PubSub.broadcast(Game.PubSub, "lobby:#{state.id}", {:lobby_updated, state})
  end
end
