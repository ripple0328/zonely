defmodule Mix.Tasks.Ns.Probe do
  use Mix.Task

  @shortdoc "Probe NameShouts endpoints with sample names"
  def run(_args) do
    Mix.Task.run("app.start")

    api_key = System.get_env("NS_API_KEY") |> to_string() |> String.trim()
    headers = [{"NS-API-KEY", api_key}, {"Accept", "application/json"}]

    samples = [
      {"albert/german", "https://www.v1.nameshouts.com/api/names/albert/german"},
      {"jorge", "https://www.v1.nameshouts.com/api/names/jorge"},
      {"maria/spanish", "https://www.v1.nameshouts.com/api/names/maria/spanish"},
      {"alice/english", "https://www.v1.nameshouts.com/api/names/alice/english"},
      {"zh-cn/张伟", "https://www.v1.nameshouts.com/api/names/%E5%BC%A0%E4%BC%9F/chinese"},
      {"ar-eg/محمد", "https://www.v1.nameshouts.com/api/names/%D9%85%D8%AD%D9%85%D8%AF/arabic"},
      {"langs", "https://www.v1.nameshouts.com/api/langs/"}
    ]

    Enum.each(samples, fn {label, url} ->
      case Req.request(method: :get, url: url, headers: headers) do
        {:ok, %{status: status, body: body}} ->
          summary = summarize_body(body)
          Mix.shell().info("NS[#{label}] status=#{status} body=#{summary}")

        {:error, %Jason.DecodeError{data: data}} ->
          trimmed = trim_leading_html(data)
          case Jason.decode(trimmed) do
            {:ok, body} ->
              summary = summarize_body(body)
              Mix.shell().info("NS[#{label}] status=200* recovered body=#{summary}")
            _ ->
              Mix.shell().info("NS[#{label}] error=malformed_json")
          end

        {:error, reason} ->
          Mix.shell().info("NS[#{label}] error=#{inspect(reason)}")
      end
    end)
  end

  defp summarize_body(%{"status" => s, "message" => m}) when is_map(m), do: "status=#{s} keys=#{m |> Map.keys() |> Enum.take(3) |> inspect}"
  defp summarize_body(%{"status" => s, "message" => _m}), do: "status=#{s} message=string"
  defp summarize_body(_), do: "unknown"

  defp trim_leading_html(binary) do
    case :binary.match(binary, "{") do
      :nomatch -> binary
      {pos, _} -> binary_part(binary, pos, byte_size(binary) - pos)
    end
  end
end
