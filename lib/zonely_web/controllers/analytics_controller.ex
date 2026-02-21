defmodule ZonelyWeb.AnalyticsController do
  use ZonelyWeb, :controller

  alias Zonely.Analytics

  def play(conn, params) do
    properties =
      params
      |> Map.take([
        "provider",
        "cache_source",
        "original_provider",
        "name_text",
        "lang",
        "platform"
      ])
      |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
      |> Enum.into(%{})

    Analytics.track_async(
      "interaction_play_audio",
      properties,
      user_context: Analytics.user_context_from_headers(conn.req_headers)
    )

    json(conn, %{ok: true})
  end

  def dashboard(conn, params) do
    {start_date, end_date} = parse_range(params["range"] || "24h")

    total_pronunciations = Analytics.total_pronunciations(start_date, end_date)
    cache_hit_rate = Analytics.cache_hit_rate(start_date, end_date)
    error_stats = Analytics.error_rate(start_date, end_date)
    conversion = Analytics.conversion_funnel(start_date, end_date)
    top_names = Analytics.top_requested_names(start_date, end_date, 5)
    top_languages = Analytics.top_languages(start_date, end_date, 5)
    provider_performance = Analytics.provider_usage(start_date, end_date)
    geo_distribution = Analytics.geographic_distribution(start_date, end_date, 50)

    json(conn, %{
      total_pronunciations: total_pronunciations,
      cache_hit_rate: cache_hit_rate,
      error_stats: %{
        errors: error_stats.errors,
        total: error_stats.total,
        error_rate: error_stats.error_rate
      },
      conversion: %{
        landed: conversion.landed,
        converted: conversion.converted,
        conversion_rate: conversion.conversion_rate
      },
      top_names:
        top_names
        |> Enum.reject(fn entry -> is_nil(entry.name) or is_nil(entry.lang) end)
        |> Enum.map(fn entry ->
          %{
            name: entry.name,
            lang: entry.lang,
            provider: entry.provider,
            count: entry.count
          }
        end),
      top_languages:
        top_languages
        |> Enum.reject(fn {lang, _count} -> is_nil(lang) end)
        |> Enum.map(fn {lang, count} ->
          %{lang: lang, count: count}
        end),
      provider_performance:
        Enum.map(provider_performance, fn entry ->
          %{
            provider: entry.provider,
            total_requests: entry.total_requests,
            avg_generation_time_ms: entry.avg_generation_time_ms,
            p95_generation_time_ms: entry.p95_generation_time_ms
          }
        end),
      geo_distribution:
        Enum.map(geo_distribution, fn {country, count} ->
          %{country: country, count: count}
        end)
    })
  end

  defp parse_range("24h") do
    end_date = DateTime.utc_now()
    start_date = DateTime.add(end_date, -24, :hour)
    {start_date, end_date}
  end

  defp parse_range("7d") do
    end_date = DateTime.utc_now()
    start_date = DateTime.add(end_date, -7, :day)
    {start_date, end_date}
  end

  defp parse_range("30d") do
    end_date = DateTime.utc_now()
    start_date = DateTime.add(end_date, -30, :day)
    {start_date, end_date}
  end

  defp parse_range(_), do: parse_range("24h")
end
