import Config

config :zonely,
  ecto_repos: [Zonely.Repo],
  generators: [timestamp_type: :utc_datetime]

config :zonely, ZonelyWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ZonelyWeb.ErrorHTML, json: ZonelyWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Zonely.PubSub,
  live_view: [signing_salt: "GFwomtZalnkfdQOiZonelyApp2025"]

config :esbuild,
  version: "0.24.1",
  zonely: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "3.4.15",
  zonely: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"