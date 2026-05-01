defmodule Game.ProdRepo do
  use Ecto.Repo, otp_app: :game, adapter: Ecto.Adapters.Postgres

  @impl true
  def init(_type, _config) do
    url =
      System.get_env("PROD_DATABASE_URL") ||
        raise "PROD_DATABASE_URL environment variable is missing"

    {:ok, [telemetry_prefix: [:game, :prod_repo], url: url, pool_size: 2,
        timeout: :infinity,
    ownership_timeout: :infinity,
    queue_target: 10_000,
    queue_interval: 10_000, ssl: false]}
  end
end
