defmodule Zonely.Repo.Migrations.IncreaseForvoUrlLength do
  use Ecto.Migration

  def change do
    alter table(:users) do
      modify :forvo_audio_url, :text
    end
  end
end
