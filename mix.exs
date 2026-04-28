defmodule Zonely.MixProject do
  use Mix.Project

  def project do
    [
      app: :zonely,
      version: "0.1.0",
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      usage_rules: usage_rules(),
      preferred_cli_env: [
        test: :test,
        precommit: :test
      ],
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  def cli do
    [
      preferred_envs: [
        test: :test,
        precommit: :test
      ]
    ]
  end

  def application do
    [
      mod: {Zonely.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:usage_rules, "~> 1.2", only: [:dev]},
      {:phoenix, "~> 1.8"},
      {:phoenix_ecto, "~> 4.6"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.2"},
      {:phoenix_live_reload, "~> 1.6", only: :dev},
      {:phoenix_live_view, "~> 1.1"},
      {:phoenix_live_dashboard, "~> 0.8.7"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:scout_apm, "~> 2.0"},
      {:telemetry_metrics, "~> 1.1"},
      {:telemetry_poller, "~> 1.3"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.4"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.10"},
      {:countries, "~> 1.6"},
      {:req, "~> 0.5"},
      {:tzdata, "~> 1.1"},
      {:tidewave, "~> 0.5", only: :dev},
      {:igniter, "~> 0.7", only: [:dev, :test]},
      {:lazy_html, ">= 0.1.0", only: :test}
    ]
  end

  defp usage_rules do
    [
      file: "AGENTS.md",
      usage_rules: ["usage_rules:all", "phoenix:all", :igniter]
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      precommit: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "cmd env -u MIX_ENV mix test"
      ],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind zonely", "esbuild zonely"],
      "assets.deploy": [
        "tailwind zonely --minify",
        "esbuild zonely --minify",
        "phx.digest"
      ],
      "db.up": ["cmd docker compose up -d db"],
      "db.down": ["cmd docker compose down db"],
      "db.logs": ["cmd docker compose logs db"],
      "prod.migrate": ["cmd just migrate"],
      "prod.status": ["cmd just status"],
      "prod.logs": ["cmd just logs"]
    ]
  end
end
