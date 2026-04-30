defmodule Zonely.Drafts do
  @moduledoc """
  Draft persistence and token-backed continuation APIs for imports and packets.
  """

  import Ecto.Query, warn: false

  alias Zonely.Drafts.{TeamDraft, TeamDraftMember}
  alias Zonely.Repo

  @token_bytes 32
  @attr_keys %{
    "availability" => :availability,
    "completion_status" => :completion_status,
    "display_name" => :display_name,
    "invite_token_hash" => :invite_token_hash,
    "latitude" => :latitude,
    "location" => :location,
    "location_country" => :location_country,
    "location_label" => :location_label,
    "longitude" => :longitude,
    "name" => :name,
    "name_variants" => :name_variants,
    "owner_token_hash" => :owner_token_hash,
    "person" => :person,
    "pronouns" => :pronouns,
    "pronunciation" => :pronunciation,
    "published_membership_id" => :published_membership_id,
    "published_person_id" => :published_person_id,
    "published_team_id" => :published_team_id,
    "review_status" => :review_status,
    "role" => :role,
    "source_idempotency_key" => :source_idempotency_key,
    "source_kind" => :source_kind,
    "source_payload" => :source_payload,
    "source_reference" => :source_reference,
    "source_token" => :source_token,
    "source_url" => :source_url,
    "status" => :status,
    "submission_owner_token_hash" => :submission_owner_token_hash,
    "team_draft_id" => :team_draft_id,
    "timezone" => :timezone,
    "work_end" => :work_end,
    "work_start" => :work_start
  }

  def create_team_draft(attrs \\ %{}) do
    owner_token = generate_token()
    invite_token = generate_token()

    attrs =
      attrs
      |> normalize_attrs()
      |> Map.put(:owner_token_hash, hash_token(owner_token))
      |> Map.put(:invite_token_hash, hash_token(invite_token))

    %TeamDraft{}
    |> TeamDraft.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, draft} -> {:ok, %{draft: draft, owner_token: owner_token, invite_token: invite_token}}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def get_draft_by_owner_token(token) when is_binary(token) do
    Repo.get_by(TeamDraft, owner_token_hash: hash_token(token))
  end

  def get_draft_by_owner_token(_token), do: nil

  def get_draft_by_invite_token(token) when is_binary(token) do
    Repo.get_by(TeamDraft, invite_token_hash: hash_token(token))
  end

  def get_draft_by_invite_token(_token), do: nil

  def get_draft_by_source_idempotency_key(key) when is_binary(key) do
    Repo.get_by(TeamDraft, source_idempotency_key: key)
  end

  def get_draft_by_source_idempotency_key(_key), do: nil

  def owner_token_matches?(%TeamDraft{} = draft, token) when is_binary(token) do
    draft.owner_token_hash == hash_token(token)
  end

  def owner_token_matches?(%TeamDraft{}, _token), do: false

  def get_draft_member!(id), do: Repo.get!(TeamDraftMember, id)

  def list_draft_members(%TeamDraft{} = draft) do
    TeamDraftMember
    |> where([member], member.team_draft_id == ^draft.id)
    |> order_by([member], asc: member.inserted_at, asc: member.id)
    |> Repo.all()
  end

  def create_draft_member(%TeamDraft{} = draft, attrs \\ %{}) do
    attrs =
      attrs
      |> normalize_attrs()
      |> Map.put(:team_draft_id, draft.id)

    %TeamDraftMember{}
    |> TeamDraftMember.changeset(attrs)
    |> Repo.insert()
  end

  def change_draft_member_completion(%TeamDraftMember{} = member, attrs \\ %{}) do
    member
    |> TeamDraftMember.changeset(completion_attrs(attrs))
    |> Map.put(:action, :validate)
  end

  def update_draft_member_completion(%TeamDraftMember{} = member, attrs) do
    member
    |> TeamDraftMember.changeset(completion_attrs(attrs))
    |> Repo.update()
  end

  def create_submission_member(%TeamDraft{} = draft, attrs \\ %{}) do
    submission_token = generate_token()

    attrs =
      attrs
      |> normalize_attrs()
      |> Map.put(:submission_owner_token_hash, hash_token(submission_token))

    case create_draft_member(draft, attrs) do
      {:ok, member} -> {:ok, %{member: member, submission_token: submission_token}}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def get_member_by_submission_token(%TeamDraft{} = draft, token) when is_binary(token) do
    Repo.get_by(TeamDraftMember,
      team_draft_id: draft.id,
      submission_owner_token_hash: hash_token(token)
    )
  end

  def get_member_by_submission_token(%TeamDraft{}, _token), do: nil

  def upsert_submission_member(%TeamDraft{} = draft, submission_token, attrs)
      when is_binary(submission_token) do
    attrs =
      attrs
      |> normalize_attrs()
      |> Map.put(:team_draft_id, draft.id)
      |> Map.put(:submission_owner_token_hash, hash_token(submission_token))

    case get_member_by_submission_token(draft, submission_token) do
      nil ->
        %TeamDraftMember{}
        |> TeamDraftMember.changeset(attrs)
        |> Repo.insert()

      %TeamDraftMember{} = member ->
        member
        |> TeamDraftMember.changeset(attrs)
        |> Repo.update()
    end
  end

  def update_member_review_status(%TeamDraftMember{} = member, review_status)
      when review_status in [:pending, :accepted, :rejected, :excluded, :published] do
    member
    |> TeamDraftMember.changeset(%{review_status: review_status})
    |> Repo.update()
  end

  def put_published_references(%TeamDraft{} = draft, published_team_id) do
    draft
    |> TeamDraft.changeset(%{status: :published, published_team_id: published_team_id})
    |> Repo.update()
  end

  def put_published_references(
        %TeamDraftMember{} = member,
        published_person_id,
        published_membership_id
      ) do
    member
    |> TeamDraftMember.changeset(%{
      review_status: :published,
      published_person_id: published_person_id,
      published_membership_id: published_membership_id
    })
    |> Repo.update()
  end

  def create_draft_from_import(projection, attrs \\ %{})

  def create_draft_from_import(%{kind: :person, person: person} = projection, attrs) do
    Repo.transaction(fn ->
      draft =
        attrs
        |> Map.put_new(:name, Map.get(person, "display_name"))
        |> Map.put_new(:source_payload, projection)
        |> create_team_draft!()

      member_attrs =
        projection
        |> member_attrs_from_person_projection()
        |> Map.put(:source_payload, projection)

      member = create_draft_member!(draft.draft, member_attrs)

      Map.put(draft, :members, [member])
    end)
  end

  def create_draft_from_import(
        %{kind: :team, team: team, memberships: memberships} = projection,
        attrs
      ) do
    Repo.transaction(fn ->
      draft =
        attrs
        |> Map.put_new(:name, Map.fetch!(team, "name"))
        |> Map.put_new(:source_payload, projection)
        |> create_team_draft!()

      members =
        Enum.map(memberships, fn membership ->
          membership
          |> member_attrs_from_membership_projection()
          |> Map.put(:source_payload, membership)
          |> then(&create_draft_member!(draft.draft, &1))
        end)

      Map.put(draft, :members, members)
    end)
  end

  def hash_token(token) when is_binary(token) do
    :crypto.hash(:sha256, token)
    |> Base.url_encode64(padding: false)
  end

  def generate_token do
    @token_bytes
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  defp create_team_draft!(attrs) do
    case create_team_draft(attrs) do
      {:ok, result} -> result
      {:error, changeset} -> Repo.rollback(changeset)
    end
  end

  defp create_draft_member!(draft, attrs) do
    case create_draft_member(draft, attrs) do
      {:ok, member} -> member
      {:error, changeset} -> Repo.rollback(changeset)
    end
  end

  defp member_attrs_from_person_projection(%{person: person} = projection) do
    projection
    |> Map.take([:location, :availability])
    |> Map.merge(%{person: person})
    |> member_attrs_from_membership_projection()
  end

  defp member_attrs_from_membership_projection(%{"person" => person} = membership) do
    attrs_from_person(person)
    |> Map.merge(attrs_from_location(Map.get(membership, "location", %{})))
    |> Map.merge(attrs_from_availability(Map.get(membership, "availability", %{})))
    |> maybe_put(:role, Map.get(membership, "role"))
    |> maybe_put(:source_reference, get_in(person, ["id"]))
  end

  defp member_attrs_from_membership_projection(%{person: person} = membership) do
    attrs_from_person(person)
    |> Map.merge(attrs_from_location(Map.get(membership, :location, %{})))
    |> Map.merge(attrs_from_availability(Map.get(membership, :availability, %{})))
    |> maybe_put(:source_reference, get_in(person, ["id"]))
  end

  defp attrs_from_person(person) do
    %{
      display_name: Map.fetch!(person, "display_name"),
      pronouns: Map.get(person, "pronouns"),
      role: Map.get(person, "role"),
      name_variants: Map.get(person, "name_variants", []),
      pronunciation: Map.get(person, "pronunciation", %{})
    }
  end

  defp attrs_from_location(location) when is_map(location) do
    %{}
    |> maybe_put(:location_country, Map.get(location, "country"))
    |> maybe_put(:location_label, Map.get(location, "label"))
    |> maybe_put(:latitude, Map.get(location, "latitude"))
    |> maybe_put(:longitude, Map.get(location, "longitude"))
  end

  defp attrs_from_location(_location), do: %{}

  defp attrs_from_availability(availability) when is_map(availability) do
    %{}
    |> maybe_put(:timezone, Map.get(availability, "timezone"))
    |> maybe_put(:work_start, Map.get(availability, "work_start"))
    |> maybe_put(:work_end, Map.get(availability, "work_end"))
  end

  defp attrs_from_availability(_availability), do: %{}

  defp normalize_attrs(attrs) when is_map(attrs) do
    Map.new(attrs, fn
      {key, value} when is_binary(key) -> {Map.get(@attr_keys, key, key), value}
      {key, value} -> {key, value}
    end)
  end

  defp completion_attrs(attrs) do
    attrs
    |> normalize_attrs()
    |> Map.take([:location_country, :location_label, :timezone, :work_start, :work_end])
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
