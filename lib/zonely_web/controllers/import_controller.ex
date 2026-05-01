defmodule ZonelyWeb.ImportController do
  use ZonelyWeb, :controller

  alias Zonely.Accounts
  alias Zonely.Drafts
  alias Zonely.Imports.SayMyNameCardImport
  alias Zonely.Imports.SayMyNameListImport

  @owner_session_key "zonely_import_owner_tokens_by_draft"

  def say_my_name(conn, %{"url" => url} = params) do
    case say_my_name_link_kind(url) do
      :card -> say_my_name_card(conn, params)
      :list -> say_my_name_list(conn, params)
      :unknown -> import_link_error(conn)
    end
  end

  def say_my_name(conn, _params), do: import_link_error(conn)

  def say_my_name_card(conn, %{"url" => url} = params) do
    target_team = target_team_from_params(params)

    with {:ok, import} <- SayMyNameCardImport.resolve(url),
         {:ok, result} <- find_or_create_draft(conn, import, "saymyname_card", target_team) do
      conn
      |> put_import_owner_token(result.draft, result.owner_token)
      |> redirect(to: ~p"/imports/#{result.draft.id}")
    else
      {:error, _reason} -> import_error(conn)
    end
  end

  def say_my_name_card(conn, _params), do: import_error(conn)

  def say_my_name_list(conn, %{"url" => url} = params) do
    target_team = target_team_from_params(params)

    with {:ok, import} <- SayMyNameListImport.resolve(url),
         {:ok, result} <- find_or_create_draft(conn, import, "saymyname_list", target_team) do
      conn
      |> put_import_owner_token(result.draft, result.owner_token)
      |> redirect(to: ~p"/imports/#{result.draft.id}")
    else
      {:error, _reason} -> list_import_error(conn)
    end
  end

  def say_my_name_list(conn, _params), do: list_import_error(conn)

  defp find_or_create_draft(conn, import, source_kind, target_team) do
    source_idempotency_key = source_idempotency_key(import, target_team)

    case Drafts.get_draft_by_source_idempotency_key(source_idempotency_key) do
      nil ->
        attrs =
          %{
            source_kind: source_kind,
            source_token: import.source_token,
            source_url: import.source_url,
            source_idempotency_key: source_idempotency_key
          }
          |> maybe_put_target_team(target_team)

        Drafts.create_draft_from_import(import.projection, attrs)

      draft ->
        owner_token = get_import_owner_token(conn, draft)

        if Drafts.owner_token_matches?(draft, owner_token) do
          {:ok, %{draft: draft, owner_token: owner_token}}
        else
          {:error, :duplicate_import}
        end
    end
  end

  defp target_team_from_params(%{"team_id" => team_id}) when is_binary(team_id) do
    Accounts.get_team(team_id)
  end

  defp target_team_from_params(_params), do: nil

  defp maybe_put_target_team(attrs, nil), do: attrs

  defp maybe_put_target_team(attrs, team) do
    attrs
    |> Map.put(:name, team.name)
    |> Map.put(:published_team_id, team.id)
  end

  defp source_idempotency_key(import, nil), do: import.source_idempotency_key

  defp source_idempotency_key(import, team) do
    import.source_idempotency_key <> ":team:" <> team.id
  end

  defp put_import_owner_token(conn, draft, owner_token) do
    tokens =
      conn
      |> get_session(@owner_session_key, %{})
      |> normalize_owner_tokens()
      |> Map.put(to_string(draft.id), owner_token)

    put_session(conn, @owner_session_key, tokens)
  end

  defp get_import_owner_token(conn, draft) do
    conn
    |> get_session(@owner_session_key, %{})
    |> normalize_owner_tokens()
    |> Map.get(to_string(draft.id))
  end

  defp normalize_owner_tokens(tokens) when is_map(tokens) do
    Map.new(tokens, fn {draft_id, token} -> {to_string(draft_id), token} end)
  end

  defp normalize_owner_tokens(_tokens), do: %{}

  defp say_my_name_link_kind(url) when is_binary(url) do
    case URI.parse(url).path do
      path when is_binary(path) ->
        path
        |> String.split("/", trim: true)
        |> infer_say_my_name_link_kind()

      _path ->
        :unknown
    end
  end

  defp say_my_name_link_kind(_url), do: :unknown

  defp infer_say_my_name_link_kind(["list", token]) when token != "", do: :list

  defp infer_say_my_name_link_kind([kind, token]) when kind in ["card", "share"] and token != "",
    do: :card

  defp infer_say_my_name_link_kind(_segments), do: :unknown

  defp import_link_error(conn) do
    conn
    |> put_status(:unprocessable_entity)
    |> html("""
    <main id="saymyname-import-error">
      <h1>We could not identify that SayMyName link</h1>
      <p>Use a SayMyName card or list share URL.</p>
    </main>
    """)
  end

  defp import_error(conn) do
    conn
    |> put_status(:unprocessable_entity)
    |> html("""
    <main id="card-import-error">
      <h1>We could not import that SayMyName card</h1>
      <p>The link may be expired, unavailable, or not a shared_profile_v1 card.</p>
    </main>
    """)
  end

  defp list_import_error(conn) do
    conn
    |> put_status(:unprocessable_entity)
    |> html("""
    <main id="list-import-error">
      <h1>We could not import that SayMyName list</h1>
      <p>The link may be expired, unavailable, empty, or not a shared_profile_v1 team/list.</p>
    </main>
    """)
  end
end
