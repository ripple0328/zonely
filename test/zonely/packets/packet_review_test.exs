defmodule Zonely.Packets.PacketReviewTest do
  use Zonely.DataCase, async: true

  alias Zonely.Drafts

  describe "owner packet review lifecycle" do
    test "owner accepts, rejects, leaves pending, and excludes submissions" do
      {:ok, %{draft: draft, owner_token: owner_token, invite_token: invite_token}} =
        Drafts.create_team_draft(%{name: "Review team"})

      {:ok, %{member: pending}} =
        Drafts.create_packet_submission(invite_token, %{display_name: "Pending Person"})

      {:ok, %{member: accepted}} =
        Drafts.create_packet_submission(invite_token, %{display_name: "Accepted Person"})

      {:ok, %{member: rejected}} =
        Drafts.create_packet_submission(invite_token, %{display_name: "Rejected Person"})

      assert {:ok, still_pending} =
               Drafts.review_packet_member(draft, owner_token, pending.id, :pending)

      assert still_pending.review_status == :pending

      assert {:ok, accepted_member} =
               Drafts.review_packet_member(draft, owner_token, accepted.id, :accepted)

      assert accepted_member.review_status == :accepted

      assert {:ok, rejected_member} =
               Drafts.review_packet_member(draft, owner_token, rejected.id, :rejected)

      assert rejected_member.review_status == :rejected

      assert {:ok, excluded_member} =
               Drafts.review_packet_member(draft, owner_token, accepted.id, :excluded)

      assert excluded_member.id == accepted.id
      assert excluded_member.review_status == :excluded
    end

    test "non-owner token attempts fail without changing review state" do
      {:ok, %{draft: draft, invite_token: invite_token}} =
        Drafts.create_team_draft(%{name: "Protected review team"})

      {:ok, %{member: member, submission_token: submission_token}} =
        Drafts.create_packet_submission(invite_token, %{display_name: "Recipient"})

      assert {:error, :unauthorized} =
               Drafts.review_packet_member(draft, submission_token, member.id, :accepted)

      assert {:error, :unauthorized} =
               Drafts.review_packet_member(draft, invite_token, member.id, :accepted)

      assert [%{review_status: :pending}] = Drafts.list_draft_members(draft)
    end

    test "review summary groups pending, accepted, rejected, and excluded states" do
      {:ok, %{draft: draft, owner_token: owner_token, invite_token: invite_token}} =
        Drafts.create_team_draft(%{name: "Grouped review team"})

      {:ok, %{member: pending}} =
        Drafts.create_packet_submission(invite_token, %{display_name: "Pending"})

      {:ok, %{member: accepted}} =
        Drafts.create_packet_submission(invite_token, %{display_name: "Accepted"})

      {:ok, %{member: rejected}} =
        Drafts.create_packet_submission(invite_token, %{display_name: "Rejected"})

      {:ok, %{member: excluded}} =
        Drafts.create_packet_submission(invite_token, %{display_name: "Excluded"})

      {:ok, _member} = Drafts.review_packet_member(draft, owner_token, accepted.id, :accepted)
      {:ok, _member} = Drafts.review_packet_member(draft, owner_token, rejected.id, :rejected)
      {:ok, _member} = Drafts.review_packet_member(draft, owner_token, excluded.id, :excluded)

      assert %{
               pending: [%{id: pending_id}],
               accepted: [%{id: accepted_id}],
               rejected: [%{id: rejected_id}],
               excluded: [%{id: excluded_id}]
             } = Drafts.packet_review_summary(draft)

      assert pending_id == pending.id
      assert accepted_id == accepted.id
      assert rejected_id == rejected.id
      assert excluded_id == excluded.id
    end
  end
end
