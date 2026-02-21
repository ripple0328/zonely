defmodule Zonely.NameCards.NameCard do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "name_cards" do
    field(:display_name, :string)
    field(:pronouns, :string)
    field(:role, :string)
    field(:language_variants, {:array, :map}, default: [])
    field(:share_token, :string)
    field(:is_public, :boolean, default: true)

    timestamps(type: :utc_datetime)
  end

  @supported_languages [
    {"en", "English", "🇺🇸"},
    {"zh-CN", "Chinese (Simplified)", "🇨🇳"},
    {"zh-TW", "Chinese (Traditional)", "🇹🇼"},
    {"ja", "Japanese", "🇯🇵"},
    {"ko", "Korean", "🇰🇷"},
    {"es", "Spanish", "🇪🇸"},
    {"fr", "French", "🇫🇷"},
    {"de", "German", "🇩🇪"},
    {"pt", "Portuguese", "🇵🇹"},
    {"ru", "Russian", "🇷🇺"},
    {"ar", "Arabic", "🇸🇦"},
    {"hi", "Hindi", "🇮🇳"},
    {"it", "Italian", "🇮🇹"},
    {"nl", "Dutch", "🇳🇱"},
    {"sv", "Swedish", "🇸🇪"},
    {"da", "Danish", "🇩🇰"},
    {"no", "Norwegian", "🇳🇴"},
    {"fi", "Finnish", "🇫🇮"},
    {"th", "Thai", "🇹🇭"},
    {"vi", "Vietnamese", "🇻🇳"}
  ]

  def supported_languages, do: @supported_languages

  def language_label(code) do
    case Enum.find(@supported_languages, fn {c, _, _} -> c == code end) do
      {_, label, flag} -> "#{flag} #{label}"
      nil -> code
    end
  end

  def language_flag(code) do
    case Enum.find(@supported_languages, fn {c, _, _} -> c == code end) do
      {_, _, flag} -> flag
      nil -> "🌐"
    end
  end

  def changeset(name_card, attrs) do
    name_card
    |> cast(attrs, [:display_name, :pronouns, :role, :language_variants, :is_public])
    |> validate_required([:display_name])
    |> validate_length(:display_name, min: 1, max: 100)
    |> validate_length(:pronouns, max: 50)
    |> validate_length(:role, max: 100)
    |> validate_language_variants()
    |> maybe_generate_share_token()
  end

  defp validate_language_variants(changeset) do
    case get_field(changeset, :language_variants) do
      variants when is_list(variants) ->
        valid_codes = Enum.map(@supported_languages, fn {code, _, _} -> code end)

        valid? =
          Enum.all?(variants, fn variant ->
            is_map(variant) and
              is_binary(Map.get(variant, "language", nil)) and
              Map.get(variant, "language") in valid_codes and
              is_binary(Map.get(variant, "name", nil)) and
              String.length(Map.get(variant, "name", "")) > 0
          end)

        if valid? do
          changeset
        else
          add_error(changeset, :language_variants, "contains invalid entries")
        end

      _ ->
        changeset
    end
  end

  defp maybe_generate_share_token(changeset) do
    case get_field(changeset, :share_token) do
      nil ->
        put_change(changeset, :share_token, generate_share_token())

      _ ->
        changeset
    end
  end

  defp generate_share_token do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end
end
