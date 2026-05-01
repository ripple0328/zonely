defmodule Zonely.Packets.PassOnPacketAccumulationTest do
  use Zonely.DataCase, async: true

  alias Zonely.Drafts

  describe "pass-on packet accumulation" do
    test "Alice, Bob, and Carol append distinct submissions and replay updates only the same owner" do
      {:ok, %{draft: draft, invite_token: invite_token}} =
        Drafts.create_team_draft(%{name: "Pass-on accumulation packet"})

      assert {:ok, %{member: alice, submission_token: alice_token}} =
               Drafts.create_packet_submission(
                 invite_token,
                 complete_submission("Alice", "Lisbon")
               )

      assert {:ok, %{member: bob, submission_token: bob_token}} =
               Drafts.create_packet_submission(invite_token, complete_submission("Bob", "London"))

      assert {:ok, %{member: carol, submission_token: carol_token}} =
               Drafts.create_packet_submission(
                 invite_token,
                 complete_submission("Carol", "Toronto")
               )

      assert alice.id != bob.id
      assert alice.id != carol.id
      assert bob.id != carol.id
      assert alice_token != bob_token
      assert alice_token != carol_token
      assert bob_token != carol_token

      assert {:ok, updated_alice} =
               Drafts.update_packet_submission(
                 invite_token,
                 alice_token,
                 complete_submission("Alice Chen", "Porto")
               )

      assert updated_alice.id == alice.id

      members_by_id =
        draft
        |> Drafts.list_draft_members()
        |> Map.new(&{&1.id, &1})

      assert map_size(members_by_id) == 3
      assert members_by_id[alice.id].display_name == "Alice Chen"
      assert members_by_id[alice.id].location_label == "Porto"
      assert members_by_id[bob.id].display_name == "Bob"
      assert members_by_id[bob.id].location_label == "London"
      assert members_by_id[carol.id].display_name == "Carol"
      assert members_by_id[carol.id].location_label == "Toronto"
    end

    test "later participant replay cannot overwrite an earlier participant" do
      {:ok, %{draft: draft, invite_token: invite_token}} =
        Drafts.create_team_draft(%{name: "Protected pass-on packet"})

      {:ok, %{member: alice}} =
        Drafts.create_packet_submission(invite_token, complete_submission("Alice", "Lisbon"))

      {:ok, %{member: bob, submission_token: bob_token}} =
        Drafts.create_packet_submission(invite_token, complete_submission("Bob", "London"))

      assert {:ok, replayed_bob} =
               Drafts.update_packet_submission(
                 invite_token,
                 bob_token,
                 complete_submission("Bob Updated", "Manchester")
               )

      assert replayed_bob.id == bob.id

      members_by_id =
        draft
        |> Drafts.list_draft_members()
        |> Map.new(&{&1.id, &1})

      assert members_by_id[alice.id].display_name == "Alice"
      assert members_by_id[alice.id].location_label == "Lisbon"
      assert members_by_id[bob.id].display_name == "Bob Updated"
      assert members_by_id[bob.id].location_label == "Manchester"
    end
  end

  defp complete_submission(display_name, location_label) do
    %{
      display_name: display_name,
      location_country: "PT",
      location_label: location_label,
      timezone: "Europe/Lisbon",
      work_start: ~T[09:00:00],
      work_end: ~T[17:00:00]
    }
  end
end
