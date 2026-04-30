defmodule Zonely.Drafts.TeamDraft do
  use Ecto.Schema
  import Ecto.Changeset

  alias Zonely.Accounts.Team
  alias Zonely.Drafts.TeamDraftMember

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @statuses [:draft, :published, :archived]

  schema "team_drafts" do
    field(:name, :string)
    field(:status, Ecto.Enum, values: @statuses, default: :draft)
    field(:owner_token_hash, :string)
    field(:invite_token_hash, :string)
    field(:source_kind, :string)
    field(:source_token, :string)
    field(:source_url, :string)
    field(:source_idempotency_key, :string)
    field(:source_payload, :map, default: %{})

    belongs_to(:published_team, Team)
    has_many(:members, TeamDraftMember)

    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses

  def changeset(draft, attrs) do
    draft
    |> cast(attrs, [
      :name,
      :status,
      :owner_token_hash,
      :invite_token_hash,
      :source_kind,
      :source_token,
      :source_url,
      :source_idempotency_key,
      :source_payload,
      :published_team_id
    ])
    |> validate_required([:name, :status, :owner_token_hash, :invite_token_hash])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_token_hash(:owner_token_hash)
    |> validate_token_hash(:invite_token_hash)
    |> validate_source_payload()
    |> unique_constraint(:owner_token_hash)
    |> unique_constraint(:invite_token_hash)
    |> unique_constraint(:source_idempotency_key)
    |> assoc_constraint(:published_team)
  end

  defp validate_token_hash(changeset, field) do
    changeset
    |> validate_length(field, is: 43)
    |> validate_format(field, ~r/^[A-Za-z0-9_-]+$/)
  end

  defp validate_source_payload(changeset) do
    case get_field(changeset, :source_payload) do
      payload when is_map(payload) -> changeset
      _payload -> add_error(changeset, :source_payload, "must be a map")
    end
  end
end
