import Config

config :zonely, Zonely.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "zonely_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :zonely, ZonelyWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
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

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20

config :phoenix, :plug_init_mode, :runtime