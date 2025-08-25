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
  secret_key_base: "zonely-test-secret-key-base-that-is-definitely-at-least-64-characters-long-for-proper-security",
  server: System.get_env("WALLABY_ENABLE_SERVER") == "true"

# Enable SQL sandbox plug in test for Wallaby
config :zonely, :sql_sandbox, true

# Configure Wallaby for browser testing
config :wallaby,
  otp_app: :zonely,
  driver: Wallaby.Chrome,
  base_url: "http://localhost:4002",
  chrome: [
    binary: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    headless: System.get_env("HEADLESS", "true") == "true"
  ],
  chromedriver: [
    path: System.get_env("CHROMEDRIVER_PATH") || "chromedriver"
  ]

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime

# Use tmp dir for audio cache during tests
config :zonely, :audio_cache_dir, Path.join(System.tmp_dir!(), "zonely_test_audio")

# Use local backend during tests
config :zonely, :audio_cache,
  backend: "local",
  s3_bucket: "zonely-cache",
  public_base_url: "https://zonely-cache.s3.amazonaws.com"
