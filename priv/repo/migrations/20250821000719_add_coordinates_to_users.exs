defmodule Zonely.Repo.Migrations.AddCoordinatesToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :latitude, :decimal, precision: 10, scale: 8
      add :longitude, :decimal, precision: 11, scale: 8
    end
  end
end
