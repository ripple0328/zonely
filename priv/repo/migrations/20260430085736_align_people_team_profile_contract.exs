defmodule Zonely.Repo.Migrations.AlignPeopleTeamProfileContract do
  use Ecto.Migration

  def change do
    rename table(:users), to: table(:people)
    rename table(:people), :name, to: :display_name

    alter table(:people) do
      add :name_variants, :jsonb, null: false, default: "[]"
    end

    create table(:teams, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create table(:memberships, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :person_id, references(:people, type: :binary_id, on_delete: :delete_all), null: false
      add :team_id, references(:teams, type: :binary_id, on_delete: :delete_all), null: false
      add :role, :string

      timestamps(type: :utc_datetime)
    end

    create index(:memberships, [:person_id])
    create index(:memberships, [:team_id])
    create unique_index(:memberships, [:team_id, :person_id])
  end
end
