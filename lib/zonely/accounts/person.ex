defmodule Zonely.Accounts.Person do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "people" do
    field(:name, :string, source: :display_name)
    field(:name_variants, {:array, :map}, default: [])
    # Person-recorded audio (highest priority)
    field(:pronunciation_audio_url, :string)
    field(:pronouns, :string)
    field(:role, :string)
    field(:timezone, :string)
    field(:country, :string)
    field(:work_start, :time)
    field(:work_end, :time)
    field(:name_native, :string)
    field(:native_language, :string)
    field(:latitude, :decimal)
    field(:longitude, :decimal)

    timestamps(type: :utc_datetime)
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :name,
      :name_variants,
      :pronunciation_audio_url,
      :pronouns,
      :role,
      :timezone,
      :country,
      :work_start,
      :work_end,
      :name_native,
      :native_language,
      :latitude,
      :longitude
    ])
    |> validate_required([:name, :timezone, :country, :work_start, :work_end])
    |> normalize_name_variants()
    |> validate_name_variants()
    |> validate_timezone()
    |> validate_country_code()
  end

  defp normalize_name_variants(changeset) do
    case get_field(changeset, :name_variants) do
      variants when is_list(variants) and variants != [] ->
        changeset

      _ ->
        display_name = get_field(changeset, :name)
        native_name = get_field(changeset, :name_native)
        native_language = get_field(changeset, :native_language)

        variants =
          [
            variant("en-US", display_name),
            variant(native_language, native_name)
          ]
          |> Enum.reject(&is_nil/1)

        put_change(changeset, :name_variants, variants)
    end
  end

  defp validate_name_variants(changeset) do
    case get_field(changeset, :name_variants) do
      variants when is_list(variants) ->
        if Enum.all?(variants, &valid_name_variant?/1) do
          changeset
        else
          add_error(changeset, :name_variants, "must contain lang and text for each variant")
        end

      _ ->
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

  defp variant(_lang, nil), do: nil

  defp variant(lang, text) when is_binary(lang) and is_binary(text) do
    if String.trim(lang) == "" or String.trim(text) == "" do
      nil
    else
      %{"lang" => String.trim(lang), "text" => String.trim(text)}
    end
  end

  defp variant(_lang, _text), do: nil

  defp validate_timezone(changeset) do
    # Basic validation - could be enhanced with proper IANA timezone validation later
    changeset
  end

  defp validate_country_code(changeset) do
    case get_change(changeset, :country) do
      nil ->
        changeset

      country ->
        if String.length(country) == 2 and String.upcase(country) == country do
          changeset
        else
          add_error(changeset, :country, "must be a valid ISO 3166-1 alpha-2 country code")
        end
    end
  end
end
