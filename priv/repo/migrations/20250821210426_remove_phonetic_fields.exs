defmodule Zonely.Repo.Migrations.RemovePhoneticFields do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove :phonetic
      remove :phonetic_native

      # Add fields for Forvo API caching
      add :forvo_audio_url, :string
      add :forvo_last_checked, :utc_datetime
    end
  end
end
