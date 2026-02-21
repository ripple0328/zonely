defmodule SayMyName.Analytics.Event do
  @moduledoc """
  Base schema for all analytics events.

  All events inherit this structure and store event-specific data in the `properties` field.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          event_name: String.t(),
          timestamp: DateTime.t(),
          session_id: String.t(),
          user_context: map(),
          metadata: map(),
          properties: map(),
          inserted_at: DateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "analytics_events" do
    field(:event_name, :string)
    field(:timestamp, :utc_datetime_usec)
    field(:session_id, :string)
    field(:user_context, :map)
    field(:metadata, :map)
    field(:properties, :map)

    field(:inserted_at, :utc_datetime_usec)
  end

  @required_fields [:event_name, :timestamp, :session_id]
  @optional_fields [:user_context, :metadata, :properties]

  @doc """
  Validates an analytics event.
  """
  def changeset(event, attrs) do
    event
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_event_name()
    |> validate_session_id()
    |> put_defaults()
  end

  defp validate_event_name(changeset) do
    changeset
    |> validate_format(:event_name, ~r/^[a-z][a-z0-9_]*$/,
      message: "must be snake_case and start with a letter"
    )
    |> validate_length(:event_name, min: 3, max: 255)
  end

  defp validate_session_id(changeset) do
    changeset
    |> validate_format(
      :session_id,
      ~r/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i,
      message: "must be a valid UUIDv4"
    )
  end

  defp put_defaults(changeset) do
    changeset
    |> put_change(:user_context, get_field(changeset, :user_context) || %{})
    |> put_change(:metadata, get_field(changeset, :metadata) || %{})
    |> put_change(:properties, get_field(changeset, :properties) || %{})
    |> put_change(:inserted_at, DateTime.utc_now())
  end
end
