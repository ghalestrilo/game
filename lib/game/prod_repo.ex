defmodule Game.ProdRepo do
  use Ecto.Repo, otp_app: :game, adapter: Ecto.Adapters.Postgres

  @impl true
  def init(_type, _config) do
    url =
      System.get_env("PROD_DATABASE_KEY") ||
        raise "PROD_DATABASE_KEY environment variable is missing"

    {:ok, [url: url, pool_size: 2, ssl: true]}
  end
end
