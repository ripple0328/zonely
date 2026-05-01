defmodule Zonely.Imports.SayMyNameCardImport do
  @moduledoc """
  Resolves SayMyName card share links into Zonely shared profile projections.
  """

  alias Zonely.NameProfileContract
  alias Zonely.SayMyNameShareClient

  @allowed_hosts ["saymyname.qingbo.us", "saymyname.localhost"]

  def resolve(link) when is_binary(link) do
    with {:ok, token} <- token_from_link(link),
         {:ok, response} <- fetch_card(link, token),
         {:ok, projection} <- NameProfileContract.parse(response) do
      {:ok,
       %{
         projection: projection,
         source_token: token,
         source_url: link,
         source_idempotency_key: "saymyname_card:" <> token
       }}
    end
  end

  def resolve(_link), do: {:error, :invalid_link}

  defp fetch_card(link, token) do
    case Application.get_env(:zonely, :say_my_name_card_resolver_fun) do
      resolver when is_function(resolver, 1) -> resolver.(link)
      _resolver -> SayMyNameShareClient.get_card_share(token)
    end
  end

  defp token_from_link(link) do
    uri = URI.parse(link)

    cond do
      uri.scheme not in ["http", "https"] ->
        {:error, :invalid_link}

      uri.host not in @allowed_hosts ->
        {:error, :unsupported_host}

      true ->
        extract_token(uri)
    end
  end

  defp extract_token(%URI{path: path}) when is_binary(path) do
    path
    |> String.split("/", trim: true)
    |> case do
      [kind, token] when kind in ["card", "share"] and token != "" -> {:ok, token}
      _segments -> {:error, :invalid_link}
    end
  end

  defp extract_token(_uri), do: {:error, :invalid_link}
end
