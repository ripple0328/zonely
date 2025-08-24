import Config

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

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :zonely, ZonelyWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # Audio cache directory for runtime-generated files
  config :zonely, :audio_cache_dir,
    System.get_env("AUDIO_CACHE_DIR") || "/tmp/zonely/audio-cache"

  # MapTiler configuration
  config :zonely, :maptiler,
    api_key: System.get_env("MAPTILER_API_KEY") || "demo_key_get_your_own_at_maptiler_com"
end

# MapTiler configuration for development
if config_env() == :dev do
  config :zonely, :maptiler,
    api_key: System.get_env("MAPTILER_API_KEY") || "demo_key_get_your_own_at_maptiler_com"
end

config :ex_aws,
  region: System.get_env("AWS_REGION") || "us-east-1",
  json_codec: Jason,
  access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, :instance_role],
  secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}, :instance_role],
  http_client: ExAws.Request.Hackney
