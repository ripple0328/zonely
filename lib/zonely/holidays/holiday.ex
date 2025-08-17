defmodule Zonely.Holidays.Holiday do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "holidays" do
    field :country, :string
    field :date, :date
    field :name, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(holiday, attrs) do
    holiday
    |> cast(attrs, [:country, :date, :name])
    |> validate_required([:country, :date, :name])
    |> validate_country_code()
    |> unique_constraint([:country, :date, :name])
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