defmodule Zonely.SayMyNameShareClient do
  @moduledoc """
  Client for SayMyName reusable name-card and name-list share snapshots.

  Zonely emits the stable portable profile contract and delegates immutable
  snapshot storage to the production SayMyName API.
  """

  alias Zonely.Accounts.User
  alias Zonely.NameProfileContract

  require Logger

  @production_base_url "https://saymyname.qingbo.us"
  @card_path "/api/v1/name-card-shares"
  @list_path "/api/v1/name-list-shares"

  @doc "Returns the production service origin used for all SayMyName share requests."
  @spec production_base_url() :: String.t()
  def production_base_url, do: @production_base_url

  @doc """
  Builds the canonical SayMyName preview image URL for a returned share URL.

  SayMyName owns the card/list renderer. Zonely uses this only as a fallback for
  older API responses that do not yet include `preview_image_url`.
  """
  @spec preview_image_url_from_share_url(String.t() | nil) :: String.t() | nil
  def preview_image_url_from_share_url(share_url) when is_binary(share_url) do
    uri = URI.parse(share_url)

    case preview_image_path(uri) do
      nil -> nil
      path -> preview_base_url(uri) <> with_modal_preview_query(path)
    end
  end

  def preview_image_url_from_share_url(_share_url), do: nil

  @spec create_card_share(User.t() | map()) :: {:ok, map()} | {:error, term()}
  def create_card_share(%User{} = user) do
    user
    |> NameProfileContract.from_user()
    |> create_card_share()
  end

  def create_card_share(payload) when is_map(payload) do
    request(:post, @card_path, payload)
  end

  @spec create_list_share(String.t() | nil, [User.t()] | map()) :: {:ok, map()} | {:error, term()}
  def create_list_share(name, users) when is_list(users) do
    payload = NameProfileContract.from_users(name, users)
    create_list_share(name, payload)
  end

  def create_list_share(_name, payload) when is_map(payload) do
    request(:post, @list_path, payload)
  end

  @spec get_card_share(String.t()) :: {:ok, map()} | {:error, term()}
  def get_card_share(token) when is_binary(token) do
    request(:get, @card_path <> "/" <> URI.encode(token), nil)
  end

  def get_card_share(_token), do: {:error, :invalid_token}

  @spec get_list_share(String.t()) :: {:ok, map()} | {:error, term()}
  def get_list_share(token) when is_binary(token) do
    request(:get, @list_path <> "/" <> URI.encode(token), nil)
  end

  def get_list_share(_token), do: {:error, :invalid_token}

  defp request(method, path, payload) do
    with {:ok, headers} <- auth_headers() do
      opts =
        [
          method: method,
          url: @production_base_url <> path,
          headers: headers,
          receive_timeout: 3_000,
          connect_options: [timeout: 1_000],
          retry: false
        ]
        |> maybe_put_json(payload)

      request_fun = Application.get_env(:zonely, :say_my_name_share_request_fun, &Req.request/1)

      case request_fun.(opts) do
        {:ok, %{status: status, body: body}} when status in [200, 201] ->
          normalize_success(body)

        {:ok, %{status: 401, body: body}} ->
          Logger.warning("SayMyName share API unauthorized: #{inspect(body)}")
          {:error, :unauthorized}

        {:ok, %{status: 422, body: body}} ->
          Logger.warning("SayMyName share API validation failed: #{inspect(body)}")
          {:error, {:validation_failed, body}}

        {:ok, %{status: status, body: body}} ->
          Logger.warning("SayMyName share API returned HTTP #{status}: #{inspect(body)}")
          {:error, {:http_error, status, body}}

        {:error, reason} ->
          Logger.warning("SayMyName share API request failed: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  defp maybe_put_json(opts, nil), do: opts
  defp maybe_put_json(opts, payload), do: Keyword.put(opts, :json, payload)

  defp auth_headers do
    case System.get_env("PRONUNCIATION_API_KEY") do
      key when is_binary(key) and key != "" -> {:ok, [{"authorization", "Bearer " <> key}]}
      _ -> {:error, :missing_api_key}
    end
  end

  defp normalize_success(body) when is_map(body), do: {:ok, body}
  defp normalize_success(body), do: {:error, {:unexpected_response, body}}

  defp preview_image_path(%URI{path: "/list", query: query}) when is_binary(query),
    do: "/og/list?" <> query

  defp preview_image_path(%URI{path: "/list/" <> token}),
    do: "/og/list/" <> URI.encode(String.trim(token), &URI.char_unreserved?/1)

  defp preview_image_path(%URI{path: path, query: query})
       when path in ["/card", "/share"] and is_binary(query),
       do: "/og/card?" <> query

  defp preview_image_path(%URI{path: "/card/" <> token}),
    do: "/og/card/" <> URI.encode(String.trim(token), &URI.char_unreserved?/1)

  defp preview_image_path(%URI{path: "/share/" <> token}),
    do: "/og/card/" <> URI.encode(String.trim(token), &URI.char_unreserved?/1)

  defp preview_image_path(_uri), do: nil

  defp preview_base_url(%URI{scheme: scheme, host: host})
       when is_binary(scheme) and is_binary(host),
       do: scheme <> "://" <> host

  defp preview_base_url(_uri), do: @production_base_url

  defp with_modal_preview_query(path) when is_binary(path) do
    if String.contains?(path, "?"), do: path <> "&smn_pv=1", else: path <> "?smn_pv=1"
  end
end
