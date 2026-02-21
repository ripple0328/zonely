defmodule Zonely.EctoTypes.JsonArray do
  @moduledoc """
  Custom Ecto type for storing JSON arrays in a JSONB column.

  The standard `:map` type only accepts maps, but JSONB columns can
  store any valid JSON value including arrays. This type accepts
  both lists and maps for backward compatibility.
  """
  use Ecto.Type

  @impl true
  def type, do: :map

  @impl true
  def cast(data) when is_list(data), do: {:ok, data}
  def cast(data) when is_map(data), do: {:ok, data}
  def cast(_), do: :error

  @impl true
  def load(data), do: {:ok, data}

  @impl true
  def dump(data) when is_list(data), do: {:ok, data}
  def dump(data) when is_map(data), do: {:ok, data}
  def dump(_), do: :error

  @impl true
  def equal?(a, b), do: a == b
end
