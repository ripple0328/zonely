import Config

config :zonely, Zonely.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: String.to_integer(System.get_env("POSTGRES_PORT") || "5434"),
  database: "zonely_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :zonely, ZonelyWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "zonely-test-secret-key-base-that-is-definitely-at-least-64-characters-long-for-proper-security",
  server: false

config :zonely, :sql_sandbox, true

config :logger, level: :warning

config :scout_apm, monitor: false

config :zonely, :posthog_browser, enabled: false

config :zonely, :packet_invite_origin, "https://zonely.localhost"

config :phoenix, :plug_init_mode, :runtime
