import Config

config :zonely, Zonely.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "zonely_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :zonely, ZonelyWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "zonely-test-secret-key-base-at-least-64-characters-long",
  server: false

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime