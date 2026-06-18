defmodule Game.MixProject do
  use Mix.Project

  def project do
    [
      app: :game,
      version: "0.1.0",
      elixir: "~> 1.20",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      listeners: [Phoenix.CodeReloader],
      # Docs
      name: "Game",
      docs: &docs/0
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Game.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:bcrypt_elixir, "~> 3.0"},
      {:phoenix, "~> 1.8.5"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.28"},
      {:floki, ">= 0.30.0", only: :test},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:backpex, "~> 0.18.0"},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "~> 1.20"},
      {:req, "~> 0.5"},
      {:finch, "~> 0.13"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.1.1"},
      {:bandit, "~> 1.5"},
      {:struct_access, "~> 1.1.2"},
      {:hexgrid, "~> 2.1"},
      {:git_hooks, "~> 0.8.1", only: :dev},
      {:json_logic, "~> 1.0"},
      {:broadway, "~> 1.1"},
      {:broadway_rabbitmq, "~> 0.8"},
      {:slugify, "~> 1.3"},
      {:oban, "2.23.0"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp docs do
    [
      main: "readme",
      extras:
        [
          "README.md",
          "CRUSH.md": [title: "Dev Guide"],
          "docs/ai-strategy-formula-action.md": [title: "AI Strategy Formulas"]
        ] ++ extras_for_dir("docs/features", "Features"),
      groups_for_extras: [
        Features: ~r"docs/features/.+"
      ],
      groups_for_modules: [
        Combat: [~r"Game\.Combat", Game.Card, Game.CombatState, Game.CombatBuilder],
        "World & Grid": [Game.Grid, ~r"Game\.Maps", ~r"Game\.MapObject", Game.Tile],
        "AI & Formulas": [Game.AI, Game.Formula, Game.FormulaAliases],
        Content: [Game.Content, ~r"Game\.Base", ~r"Game\.Deck"],
        Lobby: [Game.Lobby, Game.LobbyServer, ~r"Game\.Workers"],
        Web: [~r"GameWeb\."]
      ],
      nest_modules_by_prefix: [GameWeb, Game.Combat, Game.Maps],
      filter_modules: fn module, _metadata ->
        module not in [
          GameWeb.Endpoint,
          GameWeb.Gettext,
          GameWeb.Layouts,
          GameWeb.ErrorHTML,
          GameWeb.ErrorJSON,
          GameWeb.Telemetry,
          GameWeb.Theme,
          Game.Mailer,
          Game.Release,
          Game.ProdRepo,
          Game.Events.Publisher
        ]
      end
    ]
  end

  defp extras_for_dir(dir, _group) do
    dir
    |> Path.join("*.md")
    |> Path.wildcard()
    |> Enum.sort()
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind game", "esbuild game"],
      "assets.deploy": [
        "tailwind game --minify",
        "esbuild game --minify",
        "phx.digest"
      ]
    ]
  end
end
