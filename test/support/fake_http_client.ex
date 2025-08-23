defmodule Zonely.HttpClient.Fake do
  @behaviour Zonely.HttpClient

  @impl true
  def get(url) when is_binary(url) do
    scenario = Application.get_env(:zonely, :http_fake_scenario, :all_fail)

    cond do
      String.contains?(url, "nslibrary01.blob.core.windows.net/ns-audio/") ->
        {:ok, %{status: 200, body: "FAKEAUDIO"}}

      String.contains?(url, "forvo.cdn/") ->
        {:ok, %{status: 200, body: "FAKEAUDIO"}}

      String.contains?(url, "apifree.forvo.com/") ->
        case scenario do
          :forvo_success ->
            {:ok, %{status: 200, body: %{"items" => [%{"pathmp3" => "https://forvo.cdn/file.mp3"}]}}}

          _ ->
            {:ok, %{status: 200, body: %{"items" => []}}}
        end

      true ->
        {:error, :unknown_url}
    end
  end

  @impl true
  def get(url, _headers) when is_binary(url) do
    scenario = Application.get_env(:zonely, :http_fake_scenario, :all_fail)

    cond do
      String.contains?(url, "nameshouts.com/api/names/") ->
        case scenario do
          :nameshouts_success ->
            # Build a minimal successful response
            name = url |> URI.parse() |> Map.get(:path) |> String.split("/") |> List.last() |> URI.decode()
            key = name |> String.downcase() |> String.replace(~r/\s+/, "-")
            body = %{
              "status" => "Success",
              "message" => %{
                key => [
                  %{"lang_name" => "English", "path" => "#{key}_en"}
                ]
              }
            }

            {:ok, %{status: 200, body: body}}

          _ ->
            {:ok, %{status: 404, body: %{"status" => "Failure"}}}
        end

      true ->
        {:error, :unknown_url}
    end
  end
end
