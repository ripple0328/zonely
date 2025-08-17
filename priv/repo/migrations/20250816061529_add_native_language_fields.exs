defmodule Zonely.Repo.Migrations.AddNativeLanguageFields do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :name_native, :string, comment: "Name in native language/script"
      add :phonetic_native, :string, comment: "Phonetic pronunciation in native language"
      add :native_language, :string, comment: "Native language code (e.g., 'ja', 'sv', 'hi')"
    end
  end
end