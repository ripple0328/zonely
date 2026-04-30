defmodule Zonely.Packets.PacketPublishTest do
  use Zonely.DataCase, async: true

  import Ecto.Query

  alias Zonely.Accounts.{Membership, Person, Team}
  alias Zonely.Drafts
  alias Zonely.Drafts.TeamDraft
  alias Zonely.Repo

  describe "owner packet publish" do
    test "publishes accepted complete members only and excludes pending rejected and excluded rows" do
      {:ok, %{draft: draft, owner_token: owner_token, invite_token: invite_token}} =
        Drafts.create_team_draft(%{name: "Publish team"})

      {:ok, %{member: accepted}} =
        Drafts.create_packet_submission(invite_token, complete_submission("Accepted Person"))

      {:ok, %{member: pending}} =
        Drafts.create_packet_submission(invite_token, complete_submission("Pending Person"))

      {:ok, %{member: rejected}} =
        Drafts.create_packet_submission(invite_token, complete_submission("Rejected Person"))

      {:ok, %{member: excluded}} =
        Drafts.create_packet_submission(invite_token, complete_submission("Excluded Person"))

      {:ok, accepted_member} =
        Drafts.review_packet_member(draft, owner_token, accepted.id, :accepted)

      {:ok, _rejected_member} =
        Drafts.review_packet_member(draft, owner_token, rejected.id, :rejected)

      {:ok, excluded_member} =
        Drafts.review_packet_member(draft, owner_token, excluded.id, :accepted)

      {:ok, _excluded_member} =
        Drafts.review_packet_member(draft, owner_token, excluded_member.id, :excluded)

      assert {:ok, result} = Drafts.publish_packet(draft, owner_token)

      assert result.team.name == "Publish team"
      assert Enum.map(result.members, & &1.draft_member.id) == [accepted_member.id]

      assert [%Person{name: "Accepted Person", timezone: "Europe/Lisbon", country: "PT"}] =
               Repo.all(Person)

      assert Repo.aggregate(Team, :count) == 1
      assert Repo.aggregate(Membership, :count) == 1

      assert %{status: :published, published_team_id: published_team_id} =
               Repo.get!(TeamDraft, draft.id)

      assert published_team_id == result.team.id

      assert %{review_status: :published, published_person_id: person_id} =
               Drafts.get_draft_member!(accepted.id)

      assert person_id == hd(result.members).person.id

      assert %{review_status: :pending, published_person_id: nil} =
               Drafts.get_draft_member!(pending.id)

      assert %{review_status: :rejected, published_person_id: nil} =
               Drafts.get_draft_member!(rejected.id)

      assert %{review_status: :excluded, published_person_id: nil} =
               Drafts.get_draft_member!(excluded.id)
    end

    test "blocks publish when accepted included members are incomplete" do
      {:ok, %{draft: draft, owner_token: owner_token, invite_token: invite_token}} =
        Drafts.create_team_draft(%{name: "Incomplete team"})

      {:ok, %{member: member}} =
        Drafts.create_packet_submission(invite_token, %{display_name: "Missing Timezone"})

      {:ok, _accepted_member} =
        Drafts.review_packet_member(draft, owner_token, member.id, :accepted)

      assert {:error, {:incomplete_members, [blocked]}} =
               Drafts.publish_packet(draft, owner_token)

      assert blocked.id == member.id
      assert Repo.aggregate(Team, :count) == 0
      assert Repo.aggregate(Person, :count) == 0
      assert %{status: :draft, published_team_id: nil} = Repo.get!(TeamDraft, draft.id)

      {:ok, _excluded_member} =
        Drafts.review_packet_member(draft, owner_token, member.id, :excluded)

      assert {:ok, %{team: team, members: []}} = Drafts.publish_packet(draft, owner_token)
      assert team.name == "Incomplete team"
      assert Repo.aggregate(Person, :count) == 0
    end

    test "is owner-only and idempotent across replay or double submit" do
      {:ok, %{draft: draft, owner_token: owner_token, invite_token: invite_token}} =
        Drafts.create_team_draft(%{name: "Replay team"})

      {:ok, %{member: member, submission_token: submission_token}} =
        Drafts.create_packet_submission(invite_token, complete_submission("Replay Person"))

      {:ok, _accepted_member} =
        Drafts.review_packet_member(draft, owner_token, member.id, :accepted)

      assert {:error, :unauthorized} = Drafts.publish_packet(draft, submission_token)
      assert {:error, :unauthorized} = Drafts.publish_packet(draft, invite_token)
      assert Repo.aggregate(Team, :count) == 0

      assert {:ok, first} = Drafts.publish_packet(draft, owner_token)
      assert {:ok, second} = Drafts.publish_packet(draft, owner_token)

      assert first.team.id == second.team.id
      assert hd(first.members).person.id == hd(second.members).person.id
      assert hd(first.members).membership.id == hd(second.members).membership.id
      assert Repo.aggregate(Team, :count) == 1
      assert Repo.aggregate(Person, :count) == 1
      assert Repo.aggregate(Membership, :count) == 1
    end

    test "preserves explicit coordinates but publishes coordinate-less members without invented markers" do
      {:ok, %{draft: draft, owner_token: owner_token, invite_token: invite_token}} =
        Drafts.create_team_draft(%{name: "Privacy team"})

      {:ok, %{member: with_coordinates}} =
        Drafts.create_packet_submission(
          invite_token,
          complete_submission("Coordinate Person", %{
            "latitude" => "38.7223",
            "longitude" => "-9.1393"
          })
        )

      {:ok, %{member: without_coordinates}} =
        Drafts.create_packet_submission(
          invite_token,
          complete_submission("Private Location Person")
        )

      {:ok, _member} =
        Drafts.review_packet_member(draft, owner_token, with_coordinates.id, :accepted)

      {:ok, _member} =
        Drafts.review_packet_member(draft, owner_token, without_coordinates.id, :accepted)

      assert {:ok, _result} = Drafts.publish_packet(draft, owner_token)

      people = Repo.all(from(person in Person, order_by: person.name))

      assert [
               %Person{name: "Coordinate Person", latitude: latitude, longitude: longitude},
               %Person{name: "Private Location Person", latitude: nil, longitude: nil}
             ] = people

      assert Decimal.equal?(latitude, Decimal.new("38.7223"))
      assert Decimal.equal?(longitude, Decimal.new("-9.1393"))
    end
  end

  defp complete_submission(display_name, attrs \\ %{}) do
    Map.merge(
      %{
        "display_name" => display_name,
        "role" => "Engineering",
        "location_country" => "PT",
        "location_label" => "Lisbon",
        "timezone" => "Europe/Lisbon",
        "work_start" => "09:00",
        "work_end" => "17:00"
      },
      attrs
    )
  end
end
