defmodule Zonely.Drafts.TeamDraftMember do
  use Ecto.Schema
  import Ecto.Changeset

  alias Zonely.Accounts.{Membership, Person}
  alias Zonely.Drafts.TeamDraft

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @review_statuses [:pending, :accepted, :rejected, :excluded, :published]
  @completion_statuses [:incomplete, :complete]

  schema "team_draft_members" do
    field(:display_name, :string)
    field(:pronouns, :string)
    field(:role, :string)
    field(:name_variants, {:array, :map}, default: [])
    field(:pronunciation, :map, default: %{})
    field(:location_country, :string)
    field(:location_label, :string)
    field(:latitude, :decimal)
    field(:longitude, :decimal)
    field(:timezone, :string)
    field(:work_start, :time)
    field(:work_end, :time)
    field(:completion_status, Ecto.Enum, values: @completion_statuses, default: :incomplete)
    field(:review_status, Ecto.Enum, values: @review_statuses, default: :pending)
    field(:submission_owner_token_hash, :string)
    field(:source_kind, :string)
    field(:source_reference, :string)
    field(:source_idempotency_key, :string)
    field(:source_payload, :map, default: %{})

    belongs_to(:team_draft, TeamDraft)
    belongs_to(:published_person, Person)
    belongs_to(:published_membership, Membership)

    timestamps(type: :utc_datetime)
  end

  def review_statuses, do: @review_statuses
  def completion_statuses, do: @completion_statuses

  def changeset(member, attrs) do
    member
    |> cast(attrs, [
      :team_draft_id,
      :display_name,
      :pronouns,
      :role,
      :name_variants,
      :pronunciation,
      :location_country,
      :location_label,
      :latitude,
      :longitude,
      :timezone,
      :work_start,
      :work_end,
      :completion_status,
      :review_status,
      :submission_owner_token_hash,
      :source_kind,
      :source_reference,
      :source_idempotency_key,
      :source_payload,
      :published_person_id,
      :published_membership_id
    ])
    |> normalize_blank_strings([
      :display_name,
      :pronouns,
      :role,
      :location_country,
      :location_label,
      :timezone,
      :source_kind,
      :source_reference,
      :source_idempotency_key
    ])
    |> put_computed_completion_status()
    |> validate_required([:team_draft_id, :display_name, :completion_status, :review_status])
    |> validate_length(:display_name, min: 1, max: 255)
    |> validate_length(:role, max: 100)
    |> validate_name_variants()
    |> validate_pronunciation()
    |> validate_country_code()
    |> validate_timezone()
    |> validate_coordinate_pair()
    |> validate_token_hash()
    |> validate_source_payload()
    |> assoc_constraint(:team_draft)
    |> assoc_constraint(:published_person)
    |> assoc_constraint(:published_membership)
    |> unique_constraint(:submission_owner_token_hash)
    |> unique_constraint(:source_idempotency_key)
    |> check_constraint(:latitude, name: :team_draft_members_coordinates_pair_check)
  end

  defp normalize_blank_strings(changeset, fields) do
    Enum.reduce(fields, changeset, fn field, changeset ->
      case get_change(changeset, field) do
        value when is_binary(value) ->
          case String.trim(value) do
            "" -> put_change(changeset, field, nil)
            text -> put_change(changeset, field, text)
          end

        _value ->
          changeset
      end
    end)
  end

  defp put_computed_completion_status(changeset) do
    status =
      if complete?(changeset) do
        :complete
      else
        :incomplete
      end

    put_change(changeset, :completion_status, status)
  end

  defp complete?(changeset) do
    present?(get_field(changeset, :display_name)) and
      present?(get_field(changeset, :location_country)) and
      present?(get_field(changeset, :location_label)) and
      present?(get_field(changeset, :timezone)) and
      not is_nil(get_field(changeset, :work_start)) and
      not is_nil(get_field(changeset, :work_end))
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_value), do: false

  defp validate_name_variants(changeset) do
    case get_field(changeset, :name_variants) do
      variants when is_list(variants) ->
        if Enum.all?(variants, &valid_name_variant?/1) do
          changeset
        else
          add_error(changeset, :name_variants, "must contain lang and text for each variant")
        end

      _variants ->
        add_error(changeset, :name_variants, "must be a list")
    end
  end

  defp valid_name_variant?(%{"lang" => lang, "text" => text})
       when is_binary(lang) and is_binary(text) do
    String.trim(lang) != "" and String.trim(text) != ""
  end

  defp valid_name_variant?(%{lang: lang, text: text}) when is_binary(lang) and is_binary(text) do
    String.trim(lang) != "" and String.trim(text) != ""
  end

  defp valid_name_variant?(_variant), do: false

  defp validate_pronunciation(changeset) do
    case get_field(changeset, :pronunciation) do
      pronunciation when is_map(pronunciation) -> changeset
      _pronunciation -> add_error(changeset, :pronunciation, "must be a map")
    end
  end

  defp validate_country_code(changeset) do
    case get_change(changeset, :location_country) do
      nil ->
        changeset

      country ->
        if String.length(country) == 2 and String.upcase(country) == country do
          changeset
        else
          add_error(
            changeset,
            :location_country,
            "must be a valid ISO 3166-1 alpha-2 country code"
          )
        end
    end
  end

  defp validate_timezone(changeset) do
    case get_change(changeset, :timezone) do
      nil ->
        changeset

      timezone ->
        case DateTime.now(timezone) do
          {:ok, _datetime} -> changeset
          {:error, _reason} -> add_error(changeset, :timezone, "must be a valid IANA timezone")
        end
    end
  end

  defp validate_coordinate_pair(changeset) do
    latitude = get_field(changeset, :latitude)
    longitude = get_field(changeset, :longitude)

    cond do
      is_nil(latitude) and is_nil(longitude) ->
        changeset

      is_nil(latitude) or is_nil(longitude) ->
        add_error(changeset, :latitude, "must be supplied with longitude")

      true ->
        changeset
    end
  end

  defp validate_token_hash(changeset) do
    case get_field(changeset, :submission_owner_token_hash) do
      nil ->
        changeset

      _token_hash ->
        changeset
        |> validate_length(:submission_owner_token_hash, is: 43)
        |> validate_format(:submission_owner_token_hash, ~r/^[A-Za-z0-9_-]+$/)
    end
  end

  defp validate_source_payload(changeset) do
    case get_field(changeset, :source_payload) do
      payload when is_map(payload) -> changeset
      _payload -> add_error(changeset, :source_payload, "must be a map")
    end
  end
end
