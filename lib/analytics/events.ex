defmodule SayMyName.Analytics.Events do
  @moduledoc """
  Helper functions for building event-specific property maps.

  These functions ensure consistent structure for each event type
  and help prevent typos in property names.
  """

  alias SayMyName.Analytics.Privacy

  # Page View Events

  @doc """
  Build properties for a landing page view event.

  ## Examples

      iex> SayMyName.Analytics.Events.page_view_landing(%{
      ...>   utm_source: "twitter",
      ...>   utm_campaign: "launch",
      ...>   entry_point: "social"
      ...> })
      %{
        utm_source: "twitter",
        utm_campaign: "launch",
        utm_medium: nil,
        entry_point: "social"
      }
  """
  def page_view_landing(attrs) do
    %{
      utm_source: attrs[:utm_source],
      utm_medium: attrs[:utm_medium],
      utm_campaign: attrs[:utm_campaign],
      entry_point: attrs[:entry_point] || "direct"
    }
  end

  @doc """
  Build properties for a pronunciation page view event.
  """
  def page_view_pronunciation(attrs) do
    %{
      name_hash: Privacy.hash_name(attrs[:name] || attrs[:name_hash] || ""),
      language: attrs[:language] || "en",
      voice_id: attrs[:voice_id] || "default",
      source: attrs[:source] || "direct_link"
    }
  end

  @doc """
  Build properties for a share page view event.
  """
  def page_view_share(attrs) do
    %{
      share_token: attrs[:share_token],
      source: attrs[:source] || "link"
    }
  end

  # Interaction Events

  @doc """
  Build properties for an audio playback event.
  """
  def interaction_play_audio(attrs) do
    %{
      name_hash: Privacy.hash_name(attrs[:name] || attrs[:name_hash] || ""),
      language: attrs[:language] || "en",
      voice_id: attrs[:voice_id] || "default",
      playback_position: attrs[:playback_position] || 0.0,
      audio_duration: attrs[:audio_duration] || 0.0,
      autoplay: attrs[:autoplay] || false
    }
  end

  @doc """
  Build properties for a share interaction event.
  """
  def interaction_share(attrs) do
    %{
      share_method: attrs[:share_method] || "link",
      platform: attrs[:platform],
      name_hash: Privacy.hash_name(attrs[:name] || attrs[:name_hash] || "")
    }
  end

  @doc """
  Build properties for a copy link event.
  """
  def interaction_copy_link(attrs) do
    %{
      name_hash: Privacy.hash_name(attrs[:name] || attrs[:name_hash] || ""),
      link_type: attrs[:link_type] || "pronunciation"
    }
  end

  @doc """
  Build properties for a report issue event.
  """
  def interaction_report_issue(attrs) do
    %{
      name_hash: Privacy.hash_name(attrs[:name] || attrs[:name_hash] || ""),
      issue_type: attrs[:issue_type] || "other",
      has_feedback_text:
        is_binary(attrs[:feedback_text]) && String.length(attrs[:feedback_text]) > 0
    }
  end

  # Pronunciation Events

  @doc """
  Build properties for a pronunciation generation event.
  """
  def pronunciation_generated(attrs) do
    %{
      name_hash: Privacy.hash_name(attrs[:name] || attrs[:name_hash] || ""),
      language: attrs[:language] || "en",
      voice_id: attrs[:voice_id] || "default",
      audio_duration: attrs[:audio_duration] || 0.0,
      generation_time_ms: attrs[:generation_time_ms] || 0,
      tts_provider: attrs[:tts_provider] || "elevenlabs",
      character_count: attrs[:character_count] || 0
    }
  end

  @doc """
  Build properties for a pronunciation cache hit event.
  """
  def pronunciation_cache_hit(attrs) do
    %{
      name_hash: Privacy.hash_name(attrs[:name] || attrs[:name_hash] || ""),
      language: attrs[:language] || "en",
      voice_id: attrs[:voice_id] || "default",
      cache_age_hours: attrs[:cache_age_hours] || 0.0
    }
  end

  @doc """
  Build properties for a pronunciation error event.
  """
  def pronunciation_error(attrs) do
    %{
      name_hash: Privacy.hash_name(attrs[:name] || attrs[:name_hash] || ""),
      language: attrs[:language] || "en",
      voice_id: attrs[:voice_id] || "default",
      error_type: attrs[:error_type] || "unknown",
      error_code: attrs[:error_code],
      retry_attempt: attrs[:retry_attempt] || 0
    }
  end

  # System Events

  @doc """
  Build properties for a system API error event.
  """
  def system_api_error(attrs) do
    %{
      endpoint: attrs[:endpoint],
      http_method: attrs[:http_method] || "GET",
      status_code: attrs[:status_code],
      error_category: categorize_error(attrs[:status_code]),
      response_time_ms: attrs[:response_time_ms]
    }
  end

  @doc """
  Build properties for a rate limit event.
  """
  def system_rate_limit(attrs) do
    %{
      limit_type: attrs[:limit_type] || "api_request",
      limit_window: attrs[:limit_window] || "1h",
      current_count: attrs[:current_count] || 0,
      max_allowed: attrs[:max_allowed] || 0
    }
  end

  @doc """
  Build properties for a cache miss event.
  """
  def system_cache_miss(attrs) do
    %{
      resource_type: attrs[:resource_type] || "pronunciation",
      name_hash: Privacy.hash_name(attrs[:name] || ""),
      lookup_key_hash: attrs[:lookup_key_hash] || Privacy.hash_name(attrs[:lookup_key] || "")
    }
  end

  # Private helpers

  defp categorize_error(status_code) when status_code >= 400 and status_code < 500,
    do: "client_error"

  defp categorize_error(status_code) when status_code >= 500, do: "server_error"
  defp categorize_error(_), do: "network_error"
end
