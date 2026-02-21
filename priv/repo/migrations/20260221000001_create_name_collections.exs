defmodule Zonely.Repo.Migrations.CreateNameCollections do
  use Ecto.Migration

  def change do
    create table(:name_collections, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :string
      # JSON array of name entries: [{"name": "...", "entries": [{"lang": "...", "text": "..."}]}]
      add :entries, :jsonb, null: false, default: "[]"
      # For tracking when collection was created/updated
      timestamps(type: :utc_datetime)
    end

    create index(:name_collections, [:inserted_at])
  end
end

