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
  Returns the list of teams.
  """
  def list_teams do
    Team
    |> order_by([team], asc: team.name, asc: team.id)
    |> Repo.all()
  end

  @doc """
  Returns the count of people in each team, keyed by team id.
  """
  def team_member_counts do
    Membership
    |> group_by([membership], membership.team_id)
    |> select([membership], {membership.team_id, count(membership.person_id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Returns the people that belong to a team.
  """
  def list_people_for_team(team_id) when is_binary(team_id) do
    Person
    |> join(:inner, [person], membership in Membership, on: membership.person_id == person.id)
    |> where([_person, membership], membership.team_id == ^team_id)
    |> order_by([person, _membership], asc: person.name, asc: person.id)
    |> Repo.all()
  end

  def list_people_for_team(_team_id), do: []

  @doc """
  Gets a team by id.
  """
  def get_team(id) when is_binary(id), do: Repo.get(Team, id)
  def get_team(_id), do: nil

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
  Returns an `%Ecto.Changeset{}` for tracking team changes.
  """
  def change_team(%Team{} = team, attrs \\ %{}) do
    Team.changeset(team, attrs)
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
