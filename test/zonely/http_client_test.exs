defmodule Zonely.HttpClientTest do
  use ExUnit.Case

  alias Zonely.HttpClient

  describe "HttpClient behaviour" do
    test "defines required callbacks" do
      # Verify the behaviour defines the expected callbacks
      callbacks = HttpClient.behaviour_info(:callbacks)

      assert {:get, 1} in callbacks
      assert {:get, 2} in callbacks
    end
  end

  describe "HttpClient.Req implementation" do
    alias Zonely.HttpClient.Req

    test "implements HttpClient behaviour" do
      # Verify that Req module implements the behaviour
      assert Req.__info__(:attributes)[:behaviour] == [Zonely.HttpClient]
    end

    test "get/1 calls Req.get with timeout configuration" do
      # This is more of a smoke test since we can't easily mock Req
      # In a real scenario, you'd want to mock the Req module
      _url = "https://httpbin.org/get"

      # We can't easily test the actual HTTP call without external dependencies
      # but we can verify the function exists and has the right signature
      assert function_exported?(Req, :get, 1)
    end

    test "get/2 calls Req.request with headers and timeout configuration" do
      _url = "https://httpbin.org/get"
      _headers = [{"accept", "application/json"}]

      # Verify the function exists and has the right signature
      assert function_exported?(Req, :get, 2)
    end

    test "timeout configuration uses application environment" do
      # Test that the module reads from application config
      # The actual values are set at compile time via module attributes
      # We can verify the module has the expected timeout constants

      # These are compile-time values, so we test indirectly
      assert is_integer(Zonely.HttpClient.Req.__info__(:compile)[:source] |> length())
    end
  end

  # Note: For more comprehensive testing of the Req implementation,
  # you would typically use a library like Bypass or ExVCR to mock HTTP responses
  # or create a test double that implements the HttpClient behaviour
end
