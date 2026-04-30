defmodule ZonelyWeb.Import.CardImportFlowTest do
  use ZonelyWeb.ConnCase, async: false

  alias Zonely.Accounts
  alias Zonely.Drafts
  alias Zonely.Drafts.{TeamDraft, TeamDraftMember}
  alias Zonely.Repo

  setup do
    previous_resolver = Application.get_env(:zonely, :say_my_name_card_resolver_fun)

    on_exit(fn ->
      if previous_resolver do
        Application.put_env(:zonely, :say_my_name_card_resolver_fun, previous_resolver)
      else
        Application.delete_env(:zonely, :say_my_name_card_resolver_fun)
      end
    end)

    :ok
  end

  describe "SayMyName card import entry" do
    test "resolves a card share link, creates a reloadable owner-bound draft, and shows missing Zonely fields",
         %{conn: conn} do
      Application.put_env(:zonely, :say_my_name_card_resolver_fun, fn
        "https://saymyname.localhost/card/card-token" -> {:ok, card_payload()}
      end)

      conn =
        get(conn, ~p"/imports/saymyname/card?url=https://saymyname.localhost/card/card-token")

      assert redirected_to(conn) =~ "/imports/"
      assert Repo.aggregate(TeamDraft, :count) == 1
      assert Repo.aggregate(TeamDraftMember, :count) == 1

      draft = Repo.one!(TeamDraft)
      member = Repo.one!(TeamDraftMember)
      assert member.display_name == "Rhea Patel"
      assert member.pronouns == "she/her"
      assert member.role == "Product"
      assert member.location_country == nil
      assert member.location_label == nil
      assert member.timezone == nil
      assert member.work_start == nil
      assert member.work_end == nil
      assert member.completion_status == :incomplete
      assert member.latitude == nil
      assert member.longitude == nil

      {:ok, view, _html} = live(recycle(conn), ~p"/imports/#{draft.id}")

      assert has_element?(view, "#card-import-review")
      assert has_element?(view, "#incomplete-location-country")
      assert has_element?(view, "#incomplete-location-label")
      assert has_element?(view, "#incomplete-timezone")
      assert has_element?(view, "#incomplete-work-start")
      assert has_element?(view, "#incomplete-work-end")
      assert has_element?(view, "#name-variant-0")
      assert has_element?(view, "#name-variant-1")
      assert has_element?(view, "#pronunciation-context")
      assert has_element?(view, "#role-candidate")

      assert {:ok, _view, reload_html} = live(recycle(conn), ~p"/imports/#{draft.id}")
      assert reload_html =~ "Rhea Patel"
    end

    test "does not create a draft when the link fetch fails or payload is invalid", %{conn: conn} do
      Application.put_env(:zonely, :say_my_name_card_resolver_fun, fn
        "https://saymyname.localhost/card/missing" -> {:error, :not_found}
        "https://saymyname.localhost/card/bad" -> {:ok, %{"version" => "legacy_card"}}
      end)

      failed_conn =
        get(conn, ~p"/imports/saymyname/card?url=https://saymyname.localhost/card/missing")

      assert html_response(failed_conn, 422) =~ "We could not import that SayMyName card"

      invalid_conn =
        get(conn, ~p"/imports/saymyname/card?url=https://saymyname.localhost/card/bad")

      assert html_response(invalid_conn, 422) =~ "We could not import that SayMyName card"

      assert Repo.aggregate(TeamDraft, :count) == 0
      assert Repo.aggregate(TeamDraftMember, :count) == 0
    end
  end

  describe "card import completion" do
    test "accepts only explicit Zonely-owned completion fields and rejects invalid values", %{
      conn: conn
    } do
      %{draft: draft, owner_token: owner_token} = create_card_draft!(card_payload())

      conn = init_test_session(conn, %{"zonely_import_owner_token" => owner_token})
      {:ok, view, _html} = live(conn, ~p"/imports/#{draft.id}")

      invalid_html =
        view
        |> form("#card-import-completion-form",
          import: %{
            "location_country" => "USA",
            "location_label" => "",
            "timezone" => "+08:00",
            "work_start" => "9am",
            "work_end" => ""
          }
        )
        |> render_submit()

      assert invalid_html =~ "must be a valid ISO 3166-1 alpha-2 country code"
      assert invalid_html =~ "must be a valid IANA timezone"

      refute Repo.one!(TeamDraftMember).completion_status == :complete

      valid_html =
        view
        |> form("#card-import-completion-form",
          import: %{
            "location_country" => "PT",
            "location_label" => "Lisbon",
            "timezone" => "Europe/Lisbon",
            "work_start" => "09:00",
            "work_end" => "17:00"
          }
        )
        |> render_submit()

      assert valid_html =~ "Zonely-ready profile"

      member = Repo.one!(TeamDraftMember)
      assert member.location_country == "PT"
      assert member.location_label == "Lisbon"
      assert member.timezone == "Europe/Lisbon"
      assert member.work_start == ~T[09:00:00]
      assert member.work_end == ~T[17:00:00]
      assert member.completion_status == :complete
      assert member.name_variants |> Enum.map(& &1["text"]) == ["Rhea Patel", "રીયા પટેલ"]

      assert member.pronunciation == %{
               "source_kind" => "saymyname",
               "audio_url" => "https://cdn.example/rhea.mp3"
             }
    end

    test "preserves explicit coordinates but never infers absent coordinates", %{conn: conn} do
      payload =
        card_payload()
        |> put_in(["location"], %{
          "country" => "JP",
          "label" => "Tokyo",
          "latitude" => 35.6762,
          "longitude" => 139.6503
        })

      %{draft: draft, owner_token: owner_token} = create_card_draft!(payload)
      conn = init_test_session(conn, %{"zonely_import_owner_token" => owner_token})

      {:ok, view, _html} = live(conn, ~p"/imports/#{draft.id}")
      assert has_element?(view, "#explicit-coordinates")

      view
      |> form("#card-import-completion-form",
        import: %{
          "location_country" => "JP",
          "location_label" => "Tokyo",
          "timezone" => "Asia/Tokyo",
          "work_start" => "09:00",
          "work_end" => "18:00"
        }
      )
      |> render_submit()

      member = Repo.one!(TeamDraftMember)
      assert Decimal.equal?(member.latitude, Decimal.from_float(35.6762))
      assert Decimal.equal?(member.longitude, Decimal.from_float(139.6503))
    end

    test "blocks other sessions from mutating an import draft", %{conn: conn} do
      %{draft: draft} = create_card_draft!(card_payload())

      {:ok, view, html} = live(conn, ~p"/imports/#{draft.id}")

      assert html =~ "This import link is not available in this session"
      refute has_element?(view, "#card-import-completion-form")

      member = Repo.one!(TeamDraftMember)
      assert member.location_country == nil
      assert member.completion_status == :incomplete
    end

    test "surfaces duplicate conflicts without silently overwriting existing local data", %{
      conn: conn
    } do
      {:ok, person} =
        Accounts.create_person(%{
          name: "Rhea Patel",
          country: "US",
          timezone: "America/Los_Angeles",
          work_start: ~T[08:00:00],
          work_end: ~T[16:00:00]
        })

      %{draft: draft, owner_token: owner_token} = create_card_draft!(card_payload())
      conn = init_test_session(conn, %{"zonely_import_owner_token" => owner_token})

      {:ok, _view, html} = live(conn, ~p"/imports/#{draft.id}")

      assert html =~ "Possible duplicate"
      assert Repo.get!(Accounts.Person, person.id).timezone == "America/Los_Angeles"
    end
  end

  defp create_card_draft!(payload) do
    assert {:ok, projection} = Zonely.NameProfileContract.parse(payload)

    assert {:ok, result} =
             Drafts.create_draft_from_import(projection, %{
               source_kind: "saymyname_card",
               source_url: "https://saymyname.localhost/card/card-token",
               source_token: "card-token",
               source_idempotency_key: "saymyname_card:card-token"
             })

    result
  end

  defp card_payload do
    %{
      "version" => "shared_profile_v1",
      "person" => %{
        "id" => "smn-rhea",
        "display_name" => "Rhea Patel",
        "pronouns" => "she/her",
        "role" => "Product",
        "name_variants" => [
          %{
            "lang" => "en-US",
            "text" => "Rhea Patel",
            "pronunciation" => %{
              "source_kind" => "saymyname",
              "audio_url" => "https://cdn.example/rhea.mp3"
            }
          },
          %{"lang" => "gu-IN", "text" => "રીયા પટેલ"}
        ],
        "pronunciation" => %{
          "source_kind" => "saymyname",
          "audio_url" => "https://cdn.example/rhea.mp3"
        }
      }
    }
  end
end
