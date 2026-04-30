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

    test "fresh invite submissions create distinct pending identities" do
      {:ok, %{invite_token: invite_token}} = Drafts.create_team_draft(%{name: "Pass-on packet"})

      assert {:ok, %{member: alice, submission_token: alice_token}} =
               Drafts.create_packet_submission(invite_token, %{display_name: "Alice"})

      assert {:ok, %{member: bob, submission_token: bob_token}} =
               Drafts.create_packet_submission(invite_token, %{display_name: "Bob"})

      assert alice.id != bob.id
      assert alice_token != bob_token
      assert alice.review_status == :pending
      assert bob.review_status == :pending
    end

    test "owner and invite tokens cannot be reused as recipient submission tokens" do
      {:ok, %{draft: draft, owner_token: owner_token, invite_token: invite_token}} =
        Drafts.create_team_draft(%{name: "Authority split"})

      assert {:error, :unauthorized} =
               Drafts.upsert_submission_member(draft, owner_token, %{
                 display_name: "Owner as recipient"
               })

      assert {:error, :unauthorized} =
               Drafts.upsert_submission_member(draft, invite_token, %{
                 display_name: "Invite as owner"
               })

      assert Drafts.list_draft_members(draft) == []
    end

    test "packet submission updates require valid invite and own pending submission token" do
      {:ok, %{draft: draft, owner_token: owner_token, invite_token: invite_token}} =
        Drafts.create_team_draft(%{name: "Bound packet"})

      {:ok, %{member: member, submission_token: submission_token}} =
        Drafts.create_packet_submission(invite_token, %{display_name: "Recipient"})

      assert {:ok, updated} =
               Drafts.update_packet_submission(invite_token, submission_token, %{
                 display_name: "Recipient Updated"
               })

      assert updated.id == member.id
      assert updated.display_name == "Recipient Updated"

      assert {:error, :not_found} =
               Drafts.update_packet_submission("not-a-token", submission_token, %{
                 display_name: "Bad invite"
               })

      assert {:error, :unauthorized} =
               Drafts.update_packet_submission(invite_token, owner_token, %{
                 display_name: "Owner token swap"
               })

      assert Drafts.get_member_by_submission_token(draft, submission_token).display_name ==
               "Recipient Updated"
    end

    test "packet submission visibility separates public card fields from team-only fields" do
      {:ok, %{invite_token: invite_token}} = Drafts.create_team_draft(%{name: "Privacy packet"})

      {:ok, %{member: member}} =
        Drafts.create_packet_submission(invite_token, %{
          display_name: "Mina Park",
          pronouns: "she/her",
          role: "Engineering",
          location_country: "KR",
          location_label: "Seoul",
          timezone: "Asia/Seoul",
          work_start: ~T[09:00:00],
          work_end: ~T[17:00:00]
        })

      assert %{
               public_card: %{display_name: "Mina Park", pronouns: "she/her"},
               team_only: %{
                 role: "Engineering",
                 location_country: "KR",
                 location_label: "Seoul",
                 timezone: "Asia/Seoul"
               }
             } = Drafts.packet_submission_visibility(member)
    end

    test "invalid invite token cannot create packet submission state" do
      assert {:error, :invalid_invite_token} =
               Drafts.create_packet_submission("invalid-token", %{display_name: "Nope"})

      assert Repo.aggregate(Zonely.Drafts.TeamDraftMember, :count) == 0
    end
  end
end
