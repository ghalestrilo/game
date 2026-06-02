defmodule Game.Workers.LobbyCleanup do
  use Oban.Worker, queue: :default

  require Logger

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
