defmodule Zonely.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Zonely.Repo
  alias Zonely.Accounts.{Membership, Person, Team}

  @doc """
  Returns the list of people.
  """
  def list_people do
    Repo.all(Person)
  end

  @doc """
  Gets a single person.
  """
  def get_person!(id), do: Repo.get!(Person, id)

  @doc """
  Creates a person.
  """
  def create_person(attrs \\ %{}) do
    %Person{}
    |> Person.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a person.
  """
  def update_person(%Person{} = person, attrs) do
    person
    |> Person.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a person.
  """
  def delete_person(%Person{} = person) do
    Repo.delete(person)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.
  """
  def change_person(%Person{} = person, attrs \\ %{}) do
    Person.changeset(person, attrs)
  end

  @doc """
  Creates a team.
  """
  def create_team(attrs \\ %{}) do
    %Team{}
    |> Team.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a team membership.
  """
  def create_membership(attrs \\ %{}) do
    %Membership{}
    |> Membership.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets people by timezone for work hour calculations.
  """
  def get_people_by_timezone(timezone) do
    Person
    |> where([p], p.timezone == ^timezone)
    |> Repo.all()
  end

  @doc """
  Gets people by country for holiday calculations.
  """
  def get_people_by_country(country) do
    Person
    |> where([p], p.country == ^country)
    |> Repo.all()
  end
end
