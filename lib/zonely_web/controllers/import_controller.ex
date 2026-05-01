defmodule ZonelyWeb.ImportController do
  use ZonelyWeb, :controller

  alias Zonely.Drafts
  alias Zonely.Imports.SayMyNameCardImport
  alias Zonely.Imports.SayMyNameListImport

  @owner_session_key "zonely_import_owner_tokens_by_draft"

  def say_my_name_card(conn, %{"url" => url}) do
    with {:ok, import} <- SayMyNameCardImport.resolve(url),
         {:ok, result} <- find_or_create_draft(conn, import) do
      conn
      |> put_import_owner_token(result.draft, result.owner_token)
      |> redirect(to: ~p"/imports/#{result.draft.id}")
    else
      {:error, _reason} -> import_error(conn)
    end
  end

  def say_my_name_card(conn, _params), do: import_error(conn)

  def say_my_name_list(conn, %{"url" => url}) do
    with {:ok, import} <- SayMyNameListImport.resolve(url),
         {:ok, result} <- find_or_create_draft(conn, import, "saymyname_list") do
      conn
      |> put_import_owner_token(result.draft, result.owner_token)
      |> redirect(to: ~p"/imports/#{result.draft.id}")
    else
      {:error, _reason} -> list_import_error(conn)
    end
  end

  def say_my_name_list(conn, _params), do: list_import_error(conn)

  defp find_or_create_draft(conn, import, source_kind \\ "saymyname_card") do
    case Drafts.get_draft_by_source_idempotency_key(import.source_idempotency_key) do
      nil ->
        Drafts.create_draft_from_import(import.projection, %{
          source_kind: source_kind,
          source_token: import.source_token,
          source_url: import.source_url,
          source_idempotency_key: import.source_idempotency_key
        })

      draft ->
        owner_token = get_import_owner_token(conn, draft)

        if Drafts.owner_token_matches?(draft, owner_token) do
          {:ok, %{draft: draft, owner_token: owner_token}}
        else
          {:error, :duplicate_import}
        end
    end
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
