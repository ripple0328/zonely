defmodule SayMyName.AnalyticsTest do
  use ExUnit.Case, async: false

  alias SayMyName.Analytics
  alias SayMyName.Analytics.{Event, Privacy}

  # Mock Repo for testing
  defmodule MockRepo do
    def insert(changeset) do
      if changeset.valid? do
        event = Ecto.Changeset.apply_changes(changeset)
        {:ok, %{event | id: Ecto.UUID.generate()}}
      else
        {:error, changeset}
      end
    end

    def insert_all(_schema, entries, _opts) do
      {length(entries), nil}
    end

    def all(_query), do: []
    def one(_query), do: %{hits: 0, total: 0}
    def delete_all(_query), do: {0, nil}
  end

  setup do
    # Inject mock repo
    Application.put_env(:saymyname, :repo, MockRepo)
    :ok
  end

  describe "log_event/2" do
    test "logs a valid event" do
      {:ok, event} =
        Analytics.log_event("page_view_landing", %{
          session_id: "550e8400-e29b-41d4-a716-446655440000",
          properties: %{entry_point: "direct"}
        })

      assert event.event_name == "page_view_landing"
      assert event.session_id == "550e8400-e29b-41d4-a716-446655440000"
      assert event.properties.entry_point == "direct"
    end

    test "validates event name format" do
      {:error, changeset} =
        Analytics.log_event("Invalid-Name", %{
          session_id: "550e8400-e29b-41d4-a716-446655440000"
        })

      assert {:event_name, _} = List.keyfind(changeset.errors, :event_name, 0)
    end

    test "validates session ID format" do
      {:error, changeset} =
        Analytics.log_event("page_view_landing", %{
          session_id: "invalid-uuid"
        })

      assert {:session_id, _} = List.keyfind(changeset.errors, :session_id, 0)
    end

    test "sanitizes user context" do
      {:ok, event} =
        Analytics.log_event("page_view_landing", %{
          session_id: "550e8400-e29b-41d4-a716-446655440000",
          user_context: %{
            user_agent: "Mozilla/5.0 Test",
            referrer: "https://google.com/search?q=test",
            country: "US"
          }
        })

      assert is_binary(event.user_context.user_agent)
      # Hashed
      assert String.length(event.user_context.user_agent) == 16
      # Domain only
      assert event.user_context.referrer == "google.com"
      assert event.user_context.country == "US"
    end
  end

  describe "Privacy.hash_name/1" do
    test "produces consistent hashes" do
      hash1 = Privacy.hash_name("John")
      hash2 = Privacy.hash_name("John")

      assert hash1 == hash2
    end

    test "normalizes names before hashing" do
      hash1 = Privacy.hash_name("john")
      hash2 = Privacy.hash_name("  John  ")
      hash3 = Privacy.hash_name("JOHN")

      assert hash1 == hash2
      assert hash2 == hash3
    end

    test "produces 16-character hex strings" do
      hash = Privacy.hash_name("Test Name")

      assert String.length(hash) == 16
      assert String.match?(hash, ~r/^[0-9a-f]{16}$/)
    end
  end

  describe "Privacy.extract_referrer_domain/1" do
    test "extracts domain from full URL" do
      assert Privacy.extract_referrer_domain("https://google.com/search?q=test") == "google.com"
      assert Privacy.extract_referrer_domain("http://example.com:8080/path") == "example.com"
    end

    test "returns nil for invalid URLs" do
      assert Privacy.extract_referrer_domain("not a url") == nil
      assert Privacy.extract_referrer_domain(nil) == nil
    end
  end

  describe "Privacy.hash_user_agent/1" do
    test "produces 16-character hash" do
      hash = Privacy.hash_user_agent("Mozilla/5.0...")

      assert String.length(hash) == 16
      assert String.match?(hash, ~r/^[0-9a-f]{16}$/)
    end

    test "returns nil for invalid input" do
      assert Privacy.hash_user_agent(nil) == nil
      assert Privacy.hash_user_agent(123) == nil
    end
  end

  describe "get_retention_days/1" do
    test "returns correct retention for page views" do
      assert Analytics.get_retention_days("page_view_landing") == 90
    end

    test "returns correct retention for pronunciations" do
      assert Analytics.get_retention_days("pronunciation_generated") == 180
    end

    test "returns correct retention for system events" do
      assert Analytics.get_retention_days("system_api_error") == 30
    end

    test "returns default retention for unknown categories" do
      assert Analytics.get_retention_days("unknown_event_type") == 30
    end
  end
end
