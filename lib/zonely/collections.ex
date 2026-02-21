defmodule Zonely.Collections do
  @moduledoc """
  Context for managing name collections.
  """

  import Ecto.Query, warn: false
  alias Zonely.Repo
  alias Zonely.Collections.NameCollection

  @doc """
  Creates a new collection.
  """
  def create_collection(attrs \\ %{}) do
    %NameCollection{}
    |> NameCollection.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a collection by ID.
  """
  def get_collection!(id) do
    Repo.get!(NameCollection, id)
  end

  @doc """
  Gets a collection by ID, returns nil if not found.
  """
  def get_collection(id) do
    Repo.get(NameCollection, id)
  end

  @doc """
  Lists all collections ordered by most recent first.
  """
  def list_collections do
    NameCollection
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  @doc """
  Updates a collection.
  """
  def update_collection(%NameCollection{} = collection, attrs) do
    collection
    |> NameCollection.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a collection.
  """
  def delete_collection(%NameCollection{} = collection) do
    Repo.delete(collection)
  end

  @doc """
  Returns a changeset for tracking changes.
  """
  def change_collection(%NameCollection{} = collection, attrs \\ %{}) do
    NameCollection.changeset(collection, attrs)
  end

  @doc """
  Creates a collection from shared data (from URL).
  Automatically creates a new collection with the shared entries.
  """
  def create_from_shared_data(entries, name \\ nil) do
    collection_name = name || "Shared Collection - #{DateTime.utc_now() |> DateTime.to_date()}"

    create_collection(%{
      name: collection_name,
      entries: entries
    })
  end
end
