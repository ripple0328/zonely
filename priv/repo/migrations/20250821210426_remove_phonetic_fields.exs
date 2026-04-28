defmodule Zonely.Repo.Migrations.RemovePhoneticFields do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove :phonetic
      remove :phonetic_native
    end
  end
end
