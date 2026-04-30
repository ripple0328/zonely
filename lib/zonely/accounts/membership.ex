defmodule Zonely.Accounts.Membership do
  use Ecto.Schema
  import Ecto.Changeset

  alias Zonely.Accounts.{Person, Team}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "memberships" do
    field(:role, :string)

    belongs_to(:person, Person)
    belongs_to(:team, Team)

    timestamps(type: :utc_datetime)
  end

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:person_id, :team_id, :role])
    |> validate_required([:person_id, :team_id])
    |> validate_length(:role, max: 100)
    |> unique_constraint([:team_id, :person_id])
  end
end
