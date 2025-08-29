defmodule Mix.Tasks.Game.Seed do
  use Mix.Task
  alias Ecto.Migrator

  @shortdoc "Runs the seed script to populate the database"

  @moduledoc """
  Seeds the database with initial data.

  This task runs the seed script located at `priv/repo/seeds.exs`,
  which creates base cards and decks for the game.

  ## Usage

      mix game.seed

  ## Examples

      # Run the seed script
      $ mix game.seed
  """

  @impl Mix.Task
  def run(_args) do
    {:ok, _} = Application.ensure_all_started(:game)

    # Get the repository configuration
    repo = Game.Repo

    # Ensure the repo is started and establish a connection
    Migrator.with_repo(repo, fn _repo ->
      # Load the seed script
      seed_script = Application.app_dir(:game, "priv/repo/seeds.exs")

      if File.exists?(seed_script) do
        Mix.shell().info("Running seed script...")
        Code.eval_file(seed_script)
        Mix.shell().info("Database seeded successfully!")
      else
        Mix.shell().error("Seed script not found at: #{seed_script}")
      end
    end)
  end
end
