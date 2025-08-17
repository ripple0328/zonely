defmodule Zonely.Repo.Migrations.CreateHolidays do
  use Ecto.Migration

  def change do
    create table(:holidays, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :country, :string, null: false
      add :date, :date, null: false
      add :name, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:holidays, [:country])
    create index(:holidays, [:date])
    create unique_index(:holidays, [:country, :date, :name])
  end
end