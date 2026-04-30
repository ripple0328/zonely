defmodule ZonelyWeb.ImportController do
  use ZonelyWeb, :controller

  alias Zonely.Drafts
  alias Zonely.Imports.SayMyNameCardImport

  @owner_session_key "zonely_import_owner_token"

  def say_my_name_card(conn, %{"url" => url}) do
    with {:ok, import} <- SayMyNameCardImport.resolve(url),
         {:ok, result} <- find_or_create_draft(conn, import) do
      conn
      |> put_session(@owner_session_key, result.owner_token)
      |> redirect(to: ~p"/imports/#{result.draft.id}?owner_token=#{result.owner_token}")
    else
      {:error, _reason} -> import_error(conn)
    end
  end

  def say_my_name_card(conn, _params), do: import_error(conn)

  defp find_or_create_draft(conn, import) do
    case Drafts.get_draft_by_source_idempotency_key(import.source_idempotency_key) do
      nil ->
        Drafts.create_draft_from_import(import.projection, %{
          source_kind: "saymyname_card",
          source_token: import.source_token,
          source_url: import.source_url,
          source_idempotency_key: import.source_idempotency_key
        })

      draft ->
        owner_token = get_session(conn, @owner_session_key)

        if Drafts.owner_token_matches?(draft, owner_token) do
          {:ok, %{draft: draft, owner_token: owner_token}}
        else
          {:error, :duplicate_import}
        end
    end
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
end
