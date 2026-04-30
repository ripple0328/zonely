import Config

config :zonely, Zonely.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: String.to_integer(System.get_env("POSTGRES_PORT") || "5434"),
  database: "zonely_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :zonely, ZonelyWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT") || "4000")],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "zonely-dev-secret-key-base-at-least-64-characters-long-and-more-secure-for-phoenix-application",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:zonely, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:zonely, ~w(--watch)]}
  ]

config :zonely, ZonelyWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/zonely_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :zonely, dev_routes: true

# Tidewave AI assistant configuration
config :tidewave,
  enabled: true,
  path: "/tidewave/mcp"

# Enable LiveView debug features for better Tidewave integration
config :phoenix_live_view,
  debug_heex_annotations: true,
  debug_attributes: true

config :logger, :console, format: "[$level] $message\n"

config :scout_apm, monitor: false

config :zonely, :posthog_browser, enabled: false

config :zonely, :packet_invite_origin, "https://zonely.localhost"

config :phoenix, :stacktrace_depth, 20

config :phoenix, :plug_init_mode, :runtime
