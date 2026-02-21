defmodule Zonely.Collections.NameCollection do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "name_collections" do
    field(:name, :string)
    field(:description, :string)
    field(:entries, :map, default: %{})

    timestamps(type: :utc_datetime)
  end

  def changeset(collection, attrs) do
    collection
    |> cast(attrs, [:name, :description, :entries])
    |> validate_required([:name, :entries])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_length(:description, max: 1000)
  end

  @doc """
  Converts collection to shareable format (list of name entries).
  """
  def to_shareable_format(%__MODULE__{entries: entries}) when is_list(entries) do
    entries
  end

  def to_shareable_format(%__MODULE__{entries: entries}) when is_map(entries) do
    # Handle case where entries might be stored as map
    entries
    |> Map.values()
    |> Enum.sort_by(&(&1["inserted_at"] || ""))
  end

  def to_shareable_format(_), do: []
end
