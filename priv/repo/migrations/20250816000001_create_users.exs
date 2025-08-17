defmodule Zonely.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :phonetic, :string
      add :pronunciation_audio_url, :string
      add :pronouns, :string
      add :role, :string
      add :timezone, :string, null: false
      add :country, :string, null: false
      add :work_start, :time, null: false
      add :work_end, :time, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:users, [:country])
    create index(:users, [:timezone])
  end
end