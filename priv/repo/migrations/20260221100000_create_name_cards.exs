defmodule Zonely.Repo.Migrations.CreateNameCards do
  use Ecto.Migration

  def change do
    create table(:name_cards, primary_key: false) do
      add :id, :binary_id, primary_key: true

      # Basic info
      add :display_name, :string, null: false
      add :pronouns, :string
      add :role, :string

      # Language variants stored as JSON array:
      # [%{"language" => "en", "name" => "Sarah Chen", "pronunciation" => ""},
      #  %{"language" => "zh-CN", "name" => "陈莎拉", "pronunciation" => "Chén Shā Lā"}]
      add :language_variants, :jsonb, null: false, default: "[]"

      # Sharing
      add :share_token, :string
      add :is_public, :boolean, default: true, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:name_cards, [:share_token])
  end
end

