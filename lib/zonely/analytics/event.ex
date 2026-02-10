defmodule Zonely.Analytics.Event do
  @moduledoc """
  Schema for analytics events.
  
  All events follow a consistent structure with:
  - event_name: identifies the type of event
  - timestamp: when it occurred
  - session_id: temporary identifier for grouping
  - user_context: anonymized browser/geo data
  - metadata: app version, environment
  - properties: event-specific data
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "analytics_events" do
    field :event_name, :string
    field :timestamp, :utc_datetime_usec
    field :session_id, :string
    field :user_context, :map
    field :metadata, :map
    field :properties, :map

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @valid_event_names [
    # Page views
    "page_view_landing",
    "page_view_pronunciation",
    "page_view_share",
    # User interactions
    "interaction_play_audio",
    "interaction_share",
    "interaction_copy_link",
    "interaction_report_issue",
    # Pronunciation events
    "pronunciation_generated",
    "pronunciation_cache_hit",
    "pronunciation_error",
    # System events
    "system_api_error",
    "system_rate_limit",
    "system_cache_miss"
  ]

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:event_name, :timestamp, :session_id, :user_context, :metadata, :properties])
    |> validate_required([:event_name, :timestamp, :session_id])
    |> validate_event_name()
    |> validate_session_id()
    |> validate_user_context()
    |> validate_properties()
  end

  defp validate_event_name(changeset) do
    changeset
    |> validate_format(:event_name, ~r/^[a-z][a-z0-9_]*$/)
    |> validate_inclusion(:event_name, @valid_event_names)
  end

  defp validate_session_id(changeset) do
    validate_format(
      changeset,
      :session_id,
      ~r/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    )
  end

  defp validate_user_context(changeset) do
    case get_field(changeset, :user_context) do
      nil ->
        changeset

      context when is_map(context) ->
        # Optional validation for known fields
        changeset

      _ ->
        add_error(changeset, :user_context, "must be a map")
    end
  end

  defp validate_properties(changeset) do
    case get_field(changeset, :properties) do
      nil ->
        changeset

      props when is_map(props) ->
        changeset

      _ ->
        add_error(changeset, :properties, "must be a map")
    end
  end

  @doc """
  Valid event names that can be tracked.
  """
  def valid_event_names, do: @valid_event_names
end
