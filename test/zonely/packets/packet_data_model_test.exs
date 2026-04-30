defmodule Zonely.Packets.PacketDataModelTest do
  use Zonely.DataCase, async: true

  alias Zonely.Drafts
  alias Zonely.Drafts.TeamDraft
  alias Zonely.Repo

  describe "packet data model" do
    test "owner and invite authorities use separate opaque hashed tokens" do
      {:ok, %{draft: draft, owner_token: owner_token, invite_token: invite_token}} =
        Drafts.create_team_draft(%{name: "Private packet"})

      assert owner_token != invite_token
      refute owner_token =~ draft.id
      refute invite_token =~ draft.id
      refute owner_token =~ ~r/^[0-9a-f]{8}-[0-9a-f]{4}/
      refute invite_token =~ ~r/^[0-9a-f]{8}-[0-9a-f]{4}/

      stored = Repo.get!(TeamDraft, draft.id)
      assert stored.owner_token_hash == Drafts.hash_token(owner_token)
      assert stored.invite_token_hash == Drafts.hash_token(invite_token)
      refute stored.owner_token_hash == owner_token
      refute stored.invite_token_hash == invite_token

      assert Drafts.get_draft_by_owner_token(owner_token).id == draft.id
      assert Drafts.get_draft_by_invite_token(invite_token).id == draft.id
      assert Drafts.get_draft_by_owner_token(invite_token) == nil
      assert Drafts.get_draft_by_invite_token(owner_token) == nil
    end

    test "submission owner token updates only its own pending packet submission" do
      {:ok, %{draft: draft}} = Drafts.create_team_draft(%{name: "Append self packet"})

      {:ok, %{member: first, submission_token: first_token}} =
        Drafts.create_submission_member(draft, %{display_name: "Alice"})

      {:ok, %{member: second, submission_token: second_token}} =
        Drafts.create_submission_member(draft, %{display_name: "Bob"})

      assert {:ok, updated} =
               Drafts.upsert_submission_member(draft, first_token, %{
                 display_name: "Alice Chen",
                 location_country: "US",
                 location_label: "San Francisco",
                 timezone: "America/Los_Angeles",
                 work_start: ~T[09:00:00],
                 work_end: ~T[17:00:00]
               })

      assert updated.id == first.id
      assert updated.completion_status == :complete
      assert Drafts.get_member_by_submission_token(draft, second_token).id == second.id
      assert Drafts.get_member_by_submission_token(draft, second_token).display_name == "Bob"
      assert length(Drafts.list_draft_members(draft)) == 2
    end
  end
end
