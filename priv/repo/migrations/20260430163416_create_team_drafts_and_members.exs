defmodule Zonely.Repo.Migrations.CreateTeamDraftsAndMembers do
  use Ecto.Migration

  def change do
    create table(:team_drafts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :status, :string, null: false, default: "draft"
      add :owner_token_hash, :string, null: false
      add :invite_token_hash, :string, null: false
      add :source_kind, :string
      add :source_token, :string
      add :source_url, :string
      add :source_idempotency_key, :string
      add :source_payload, :jsonb, null: false, default: fragment("'{}'::jsonb")
      add :published_team_id, references(:teams, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:team_drafts, [:owner_token_hash])
    create unique_index(:team_drafts, [:invite_token_hash])
    create index(:team_drafts, [:published_team_id])
    create index(:team_drafts, [:status])

    create unique_index(:team_drafts, [:source_idempotency_key],
             where: "source_idempotency_key IS NOT NULL"
           )

    create constraint(:team_drafts, :team_drafts_status_check,
             check: "status IN ('draft', 'published', 'archived')"
           )

    create table(:team_draft_members, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :team_draft_id, references(:team_drafts, type: :binary_id, on_delete: :delete_all), null: false
      add :display_name, :string, null: false
      add :pronouns, :string
      add :role, :string
      add :name_variants, :jsonb, null: false, default: fragment("'[]'::jsonb")
      add :pronunciation, :jsonb, null: false, default: fragment("'{}'::jsonb")
      add :location_country, :string
      add :location_label, :string
      add :latitude, :decimal, precision: 10, scale: 8
      add :longitude, :decimal, precision: 11, scale: 8
      add :timezone, :string
      add :work_start, :time
      add :work_end, :time
      add :completion_status, :string, null: false, default: "incomplete"
      add :review_status, :string, null: false, default: "pending"
      add :submission_owner_token_hash, :string
      add :source_kind, :string
      add :source_reference, :string
      add :source_idempotency_key, :string
      add :source_payload, :jsonb, null: false, default: fragment("'{}'::jsonb")
      add :published_person_id, references(:people, type: :binary_id, on_delete: :nilify_all)
      add :published_membership_id, references(:memberships, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:team_draft_members, [:team_draft_id])
    create index(:team_draft_members, [:published_person_id])
    create index(:team_draft_members, [:published_membership_id])
    create index(:team_draft_members, [:review_status])
    create index(:team_draft_members, [:completion_status])
    create unique_index(:team_draft_members, [:submission_owner_token_hash])

    create unique_index(:team_draft_members, [:team_draft_id, :source_idempotency_key],
             where: "source_idempotency_key IS NOT NULL"
           )

    create constraint(:team_draft_members, :team_draft_members_review_status_check,
             check: "review_status IN ('pending', 'accepted', 'rejected', 'excluded', 'published')"
           )

    create constraint(:team_draft_members, :team_draft_members_completion_status_check,
             check: "completion_status IN ('incomplete', 'complete')"
           )

    create constraint(:team_draft_members, :team_draft_members_coordinates_pair_check,
             check:
               "(latitude IS NULL AND longitude IS NULL) OR (latitude IS NOT NULL AND longitude IS NOT NULL)"
           )

  end
end
