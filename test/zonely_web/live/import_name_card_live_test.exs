defmodule ZonelyWeb.ImportNameCardLiveTest do
  use ZonelyWeb.ConnCase, async: false

  alias Zonely.NameCards
  alias Zonely.NameCards.NameCard
  alias Zonely.Collections
  alias Zonely.Collections.NameCollection

  # Clean up stale data from previous test runs
  setup do
    Zonely.Repo.delete_all(NameCollection)
    Zonely.Repo.delete_all(NameCard)
    :ok
  end

  describe "mount with invalid token" do
    test "shows not found for unknown token", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/card/nonexistent-token")

      assert html =~ "Name Card Not Found"
      assert html =~ "expired or been removed"
    end
  end

  describe "mount with valid token" do
    test "shows card preview", %{conn: conn} do
      {:ok, card} =
        NameCards.save_name_card(%{
          display_name: "Sarah Chen",
          pronouns: "she/her",
          role: "Designer",
          language_variants: [
            %{"language" => "zh-CN", "name" => "陈莎拉", "pronunciation" => "Chén Shā Lā"}
          ]
        })

      {:ok, _view, html} = live(conn, ~p"/card/#{card.share_token}")

      assert html =~ "Sarah Chen"
      assert html =~ "she/her"
      assert html =~ "Designer"
      assert html =~ "陈莎拉"
      assert html =~ "Chén Shā Lā"
    end

    test "shows import form with new collection option", %{conn: conn} do
      {:ok, card} = NameCards.save_name_card(%{display_name: "Sarah"})

      {:ok, view, _html} = live(conn, ~p"/card/#{card.share_token}")

      assert has_element?(view, "#import-form")
      assert has_element?(view, "#import-btn")
    end

    test "shows existing collections in import form", %{conn: conn} do
      {:ok, card} = NameCards.save_name_card(%{display_name: "Sarah"})
      {:ok, _col} = Collections.create_collection(%{name: "My Friends", entries: []})

      {:ok, _view, html} = live(conn, ~p"/card/#{card.share_token}")

      assert html =~ "My Friends"
    end
  end

  describe "import card" do
    test "imports to a new collection", %{conn: conn} do
      {:ok, card} = NameCards.save_name_card(%{display_name: "Sarah Chen"})

      {:ok, view, _html} = live(conn, ~p"/card/#{card.share_token}")

      view
      |> form("#import-form", %{new_collection_name: "Work Friends"})
      |> render_submit()

      html = render(view)
      assert html =~ "Imported!"
      assert html =~ "imported successfully"

      # Verify collection was created
      collections = Collections.list_collections()
      assert length(collections) == 1
      assert hd(collections).name == "Work Friends"
    end

    test "imports to a new collection with default name", %{conn: conn} do
      {:ok, card} = NameCards.save_name_card(%{display_name: "Sarah Chen"})

      {:ok, view, _html} = live(conn, ~p"/card/#{card.share_token}")

      view
      |> form("#import-form", %{new_collection_name: ""})
      |> render_submit()

      assert render(view) =~ "Imported!"

      collections = Collections.list_collections()
      assert hd(collections).name =~ "Sarah Chen"
    end

    test "imports to an existing collection", %{conn: conn} do
      {:ok, card} = NameCards.save_name_card(%{display_name: "Sarah"})
      {:ok, col} = Collections.create_collection(%{name: "Team", entries: []})

      {:ok, view, _html} = live(conn, ~p"/card/#{card.share_token}")

      # Select the existing collection
      view |> render_click("select_collection", %{collection: col.id})

      view
      |> form("#import-form", %{new_collection_name: ""})
      |> render_submit()

      assert render(view) =~ "Imported!"

      # Verify entry was added to existing collection
      updated = Collections.get_collection!(col.id)
      assert length(updated.entries) == 1
      assert hd(updated.entries)["name"] == "Sarah"
    end
  end

  describe "non-public card" do
    test "shows not found for private card", %{conn: conn} do
      {:ok, card} = NameCards.save_name_card(%{display_name: "Sarah", is_public: false})

      {:ok, _view, html} = live(conn, ~p"/card/#{card.share_token}")

      assert html =~ "Name Card Not Found"
    end
  end
end
