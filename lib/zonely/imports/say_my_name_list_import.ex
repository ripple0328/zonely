defmodule Zonely.Imports.SayMyNameListImport do
  @moduledoc """
  Resolves SayMyName list share links into Zonely team draft projections.

  A list import is allowed to keep valid members when sibling rows are malformed.
  Invalid rows are retained as review metadata so Zonely never invents placeholder
  people just to make a roster look complete.
  """

  alias Zonely.NameProfileContract
  alias Zonely.SayMyNameShareClient

  @allowed_hosts ["saymyname.qingbo.us", "saymyname.localhost"]

  def resolve(link) when is_binary(link) do
    with {:ok, token} <- token_from_link(link),
         {:ok, response} <- fetch_list(link, token),
         {:ok, projection} <- parse_partial_team(response) do
      {:ok,
       %{
         projection: projection,
         source_token: token,
         source_url: link,
         source_idempotency_key: "saymyname_list:" <> token
       }}
    end
  end

  def resolve(_link), do: {:error, :invalid_link}

  defp fetch_list(link, token) do
    case Application.get_env(:zonely, :say_my_name_list_resolver_fun) do
      resolver when is_function(resolver, 1) -> resolver.(link)
      _resolver -> SayMyNameShareClient.get_list_share(token)
    end
  end

  defp parse_partial_team(response) do
    with {:ok, payload} <- unwrap_payload(response),
         {:ok, team} <- parse_team(payload),
         {:ok, memberships} <- fetch_memberships(payload),
         {:ok, result} <- parse_memberships(team, memberships) do
      {:ok,
       %{
         kind: :team,
         version: "shared_profile_v1",
         team: team,
         memberships: result.valid_memberships,
         invalid_memberships: result.invalid_memberships
       }}
    end
  end

  defp unwrap_payload(%{"payload" => payload}) when is_map(payload), do: {:ok, payload}

  defp unwrap_payload(%{"data" => %{"payload" => payload}}) when is_map(payload),
    do: {:ok, payload}

  defp unwrap_payload(payload) when is_map(payload), do: {:ok, payload}
  defp unwrap_payload(_payload), do: {:error, :invalid_payload}

  defp parse_team(%{"version" => "shared_profile_v1", "team" => team} = payload)
       when is_map(team) do
    case NameProfileContract.parse(Map.put(payload, "memberships", [placeholder_membership()])) do
      {:ok, %{team: team}} ->
        {:ok, team}

      {:error, {:invalid_membership, 0, _reason}} ->
        NameProfileContract.parse(%{
          "version" => "shared_profile_v1",
          "team" => team,
          "memberships" => [placeholder_membership()]
        })
        |> case do
          {:ok, %{team: team}} -> {:ok, team}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_team(%{"version" => "shared_profile_v1"}), do: {:error, :unsupported_shape}
  defp parse_team(%{"version" => _version}), do: {:error, :unsupported_version}
  defp parse_team(_payload), do: {:error, :unsupported_shape}

  defp fetch_memberships(%{"memberships" => memberships}) when is_list(memberships) do
    if memberships == [] do
      {:error, :empty_memberships}
    else
      {:ok, memberships}
    end
  end

  defp fetch_memberships(%{"memberships" => _memberships}), do: {:error, :invalid_memberships}
  defp fetch_memberships(_payload), do: {:error, :unsupported_shape}

  defp parse_memberships(team, memberships) do
    result =
      memberships
      |> Enum.with_index()
      |> Enum.reduce(%{valid_memberships: [], invalid_memberships: []}, fn {membership, index},
                                                                           acc ->
        case parse_membership(team, membership) do
          {:ok, membership} ->
            %{acc | valid_memberships: [membership | acc.valid_memberships]}

          {:error, reason} ->
            invalid = %{"index" => index, "reason" => reason_to_string(reason)}
            %{acc | invalid_memberships: [invalid | acc.invalid_memberships]}
        end
      end)
      |> then(fn acc ->
        %{
          valid_memberships: Enum.reverse(acc.valid_memberships),
          invalid_memberships: Enum.reverse(acc.invalid_memberships)
        }
      end)

    if result.valid_memberships == [] do
      {:error, :no_valid_members}
    else
      {:ok, result}
    end
  end

  defp parse_membership(team, membership) do
    payload = %{
      "version" => "shared_profile_v1",
      "team" => team,
      "memberships" => [membership]
    }

    case NameProfileContract.parse(payload) do
      {:ok, %{memberships: [membership]}} -> {:ok, membership}
      {:error, {:invalid_membership, 0, reason}} -> {:error, reason}
      {:error, reason} -> {:error, reason}
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
      ["list", token] when token != "" -> {:ok, token}
      _segments -> {:error, :invalid_link}
    end
  end

  defp extract_token(_uri), do: {:error, :invalid_link}

  defp placeholder_membership do
    %{"person" => %{"display_name" => "__zonely_placeholder__"}}
  end

  defp reason_to_string(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp reason_to_string(reason), do: inspect(reason)
end
