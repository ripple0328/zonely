defmodule Zonely.Repo.Migrations.AddSortOrderToTeamDraftMembers do
  use Ecto.Migration

  def change do
    alter table(:team_draft_members) do
      add(:sort_order, :integer, null: false, default: 0)
    end

    create(index(:team_draft_members, [:team_draft_id, :sort_order]))
  end
end
