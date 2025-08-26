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
      "//#{host}",
      "//*.#{host}"
    ],
    secret_key_base: secret_key_base

  # Audio cache directory for runtime-generated files
  config :zonely, :audio_cache_dir,
    System.get_env("AUDIO_CACHE_DIR") || "/tmp/zonely/audio-cache"

  # External audio cache (object storage) configuration
  # Backend can be "s3" or "local". Default prod -> s3.
  config :zonely, :audio_cache,
    backend: System.get_env("AUDIO_CACHE_BACKEND") || "s3",
    s3_bucket: System.get_env("AUDIO_CACHE_S3_BUCKET") || "zonely-cache",
    public_base_url:
      System.get_env("AUDIO_CACHE_PUBLIC_BASE_URL") ||
        "https://zonely-cache.s3.amazonaws.com",
    s3_endpoint: System.get_env("AWS_S3_ENDPOINT")

  # Provider race timeout override (ms)
  provider_race_timeout =
    case System.get_env("PROVIDER_RACE_TIMEOUT_MS") do
      nil -> nil
      "" -> nil
      val -> String.to_integer(val)
    end

  if provider_race_timeout do
    config :zonely, :provider_race_timeout_ms, provider_race_timeout
  end

  # Negative cache TTL (ms)
  negative_cache_ttl =
    case System.get_env("NEGATIVE_CACHE_TTL_MS") do
      nil -> nil
      "" -> nil
      val -> String.to_integer(val)
    end

  if negative_cache_ttl do
    config :zonely, :negative_cache_ttl_ms, negative_cache_ttl
  end

  # Optional shorter TTL for timeouts
  negative_cache_soft_ttl =
    case System.get_env("NEGATIVE_CACHE_SOFT_TTL_MS") do
      nil -> nil
      "" -> nil
      val -> String.to_integer(val)
    end

  if negative_cache_soft_ttl do
    config :zonely, :negative_cache_soft_ttl_ms, negative_cache_soft_ttl
  end

  # MapTiler configuration
  config :zonely, :maptiler,
    api_key: System.get_env("MAPTILER_API_KEY") || "demo_key_get_your_own_at_maptiler_com"
end

# MapTiler configuration for development
if config_env() == :dev do
  config :zonely, :maptiler,
    api_key: System.get_env("MAPTILER_API_KEY") || "demo_key_get_your_own_at_maptiler_com"
end

aws_region = System.get_env("AWS_REGION") || "us-west-1"
aws_s3_endpoint = System.get_env("AWS_S3_ENDPOINT")

s3_opts =
  case aws_s3_endpoint do
    nil -> [region: aws_region]
    "" -> [region: aws_region]
    endpoint -> [region: aws_region, host: endpoint]
  end

config :ex_aws,
  region: aws_region,
  json_codec: Jason,
  access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, :instance_role],
  secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}, :instance_role],
  http_client: ExAws.Request.Hackney,
  s3: s3_opts
