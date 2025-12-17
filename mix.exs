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
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  def cli do
    [
      preferred_envs: ["test.browser": :test]
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
      {:usage_rules, "~> 0.1", only: [:dev]},
      {:phoenix, "~> 1.8.1"},
      {:phoenix_ecto, "~> 4.6"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.2"},
      {:phoenix_live_reload, "~> 1.6", only: :dev},
      {:phoenix_live_view, "~> 1.1.8"},
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
      {:telemetry_metrics, "~> 1.1"},
      {:telemetry_poller, "~> 1.3"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.4"},
      {:ex_aws, "~> 2.5"},
      {:ex_aws_s3, "~> 2.5"},
      {:ex_aws_polly, "~> 0.5"},
      {:hackney, "~> 1.25"},
      {:sweet_xml, "~> 0.7"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.8"},
      {:countries, "~> 1.6"},
      {:req, "~> 0.5"},
      {:tzdata, "~> 1.1"},
      {:tidewave, "~> 0.5", only: :dev},
      {:igniter, "~> 0.6", only: [:dev, :test]},
      {:wallaby, "~> 0.30", runtime: false, only: :test}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
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
      "db.prod.up": ["cmd docker compose -f docker-compose.prod.yml up -d"],
      "db.prod.down": ["cmd docker compose -f docker-compose.prod.yml down"],
      "db.prod.logs": ["cmd docker compose -f docker-compose.prod.yml logs"],
      "db.prod.reset": [
        "cmd docker compose -f docker-compose.prod.yml down -v",
        "cmd docker compose -f docker-compose.prod.yml up -d"
      ],
      "prod.tunnel": ["db.prod.up", "cmd ./start_prod_tunnel.sh"]
    ]
  end
end
