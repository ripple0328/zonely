defmodule Zonely.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :name, :string
    field :pronunciation_audio_url, :string  # User-recorded audio (highest priority)
    field :pronouns, :string
    field :role, :string
    field :timezone, :string
    field :country, :string
    field :work_start, :time
    field :work_end, :time
    field :name_native, :string
    field :native_language, :string
    field :latitude, :decimal
    field :longitude, :decimal

    # Forvo API caching fields
    field :forvo_audio_url, :string  # Note: database type is :text for long URLs
    field :forvo_last_checked, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :pronunciation_audio_url, :pronouns, :role, :timezone, :country, :work_start, :work_end, :name_native, :native_language, :latitude, :longitude, :forvo_audio_url, :forvo_last_checked])
    |> validate_required([:name, :timezone, :country, :work_start, :work_end])
    |> validate_timezone()
    |> validate_country_code()
  end

  defp validate_timezone(changeset) do
    # Basic validation - could be enhanced with proper IANA timezone validation later
    changeset
  end

  defp validate_country_code(changeset) do
    case get_change(changeset, :country) do
      nil -> changeset
      country ->
        if String.length(country) == 2 and String.upcase(country) == country do
          changeset
        else
          add_error(changeset, :country, "must be a valid ISO 3166-1 alpha-2 country code")
        end
    end
  end
end
