defmodule Zonely.Accounts.Team do
  use Ecto.Schema
  import Ecto.Changeset

  alias Zonely.Accounts.Membership

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "teams" do
    field(:name, :string)

    has_many(:memberships, Membership)

    timestamps(type: :utc_datetime)
  end

  def changeset(team, attrs) do
    team
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 255)
  end
end
