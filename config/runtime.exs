import Config

posthog_api_key = System.get_env("POSTHOG_API_KEY")
posthog_api_host = System.get_env("POSTHOG_HOST") || "https://us.i.posthog.com"
posthog_env = System.get_env("APP_ENV") || if(config_env() == :prod, do: "prod", else: to_string(config_env()))

posthog_enabled? =
  config_env() == :prod and
    is_binary(posthog_api_key) and
    posthog_api_key != "" and
    System.get_env("POSTHOG_ENABLED", "true") in ~w(true 1 yes)

config :zonely, :posthog_browser,
  enabled: posthog_enabled?,
  api_key: posthog_api_key,
  api_host: posthog_api_host,
  app: "zonely",
  env: posthog_env

if System.get_env("PHX_SERVER") && config_env() == :prod do
  config :zonely, ZonelyWeb.Endpoint, server: true
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :zonely, Zonely.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host =
    System.get_env("PHX_HOST") ||
      raise "environment variable PHX_HOST is missing. Set it to your public hostname."

  port = String.to_integer(System.get_env("PORT") || "4000")

  config :zonely, ZonelyWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    check_origin: [
      "https://#{host}",
      "//#{host}",
      "https://zonely.qingbo.us",
      "//zonely.qingbo.us"
    ],
    secret_key_base: secret_key_base

  config :zonely, :maptiler,
    api_key: System.get_env("MAPTILER_API_KEY") || "demo_key_get_your_own_at_maptiler_com"
end

if config_env() == :dev do
  config :zonely, :maptiler,
    api_key: System.get_env("MAPTILER_API_KEY") || "demo_key_get_your_own_at_maptiler_com"
end
