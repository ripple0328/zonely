defmodule ZonelyWeb.MyNameCardLiveTest do
  use ZonelyWeb.ConnCase, async: false

  alias Zonely.NameCards
  alias Zonely.NameCards.NameCard

  # Clean up stale data from previous test runs so the
  # singleton pattern (get_name_card/0) works correctly
  setup do
    Zonely.Repo.delete_all(NameCard)
    :ok
  end

  describe "mount" do
    test "renders empty form when no card exists", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/my-name-card")

      assert html =~ "My Name Card"
      assert has_element?(view, "#name-card-form")
      assert has_element?(view, "#save-card-btn")
      # No share button for unsaved card
      refute has_element?(view, "#share-btn")
      # No delete button for unsaved card
      refute has_element?(view, "#delete-card-btn")
    end

    test "renders existing card data", %{conn: conn} do
      {:ok, _card} =
        NameCards.save_name_card(%{
          display_name: "Sarah Chen",
          pronouns: "she/her",
          role: "Designer"
        })

      {:ok, view, html} = live(conn, ~p"/my-name-card")

      assert html =~ "Sarah Chen"
      assert has_element?(view, "#share-btn")
      assert has_element?(view, "#delete-card-btn")
    end
  end

  describe "form validation" do
    test "validates on change", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/my-name-card")

      result =
        view
        |> form("#name-card-form", name_card: %{display_name: ""})
        |> render_change()

      assert result =~ "can&#39;t be blank"
    end
  end

  describe "save" do
    test "creates a new card", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/my-name-card")

      view
      |> form("#name-card-form", name_card: %{display_name: "Sarah Chen", pronouns: "she/her"})
      |> render_submit()

      # Flash message should appear
      assert render(view) =~ "Name card saved!"
      # Share button should now exist
      assert has_element?(view, "#share-btn")

      # Verify in database
      card = NameCards.get_name_card()
      assert card.display_name == "Sarah Chen"
      assert card.pronouns == "she/her"
    end

    test "updates an existing card", %{conn: conn} do
      {:ok, _} = NameCards.save_name_card(%{display_name: "Sarah"})
      {:ok, view, _html} = live(conn, ~p"/my-name-card")

      view
      |> form("#name-card-form", name_card: %{display_name: "Sarah Chen"})
      |> render_submit()

      assert render(view) =~ "Name card saved!"

      card = NameCards.get_name_card()
      assert card.display_name == "Sarah Chen"
    end
  end

  describe "language variants" do
    test "shows add language modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/my-name-card")

      refute has_element?(view, "#add-lang-modal")

      view |> element("#add-language-btn") |> render_click()

      assert has_element?(view, "#add-lang-modal")
      assert has_element?(view, "#add-lang-form")
    end

    test "adds a language variant", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/my-name-card")

      # Open modal
      view |> element("#add-language-btn") |> render_click()

      # Submit the add language form
      view
      |> form("#add-lang-form", %{name: "陈莎拉", pronunciation: "Chén Shā Lā"})
      |> render_submit()

      # Modal should close and variant should appear
      refute has_element?(view, "#add-lang-modal")
      html = render(view)
      assert html =~ "陈莎拉"
      assert html =~ "Chén Shā Lā"
    end

    test "removes a language variant", %{conn: conn} do
      {:ok, _} =
        NameCards.save_name_card(%{
          display_name: "Sarah",
          language_variants: [%{"language" => "zh-CN", "name" => "莎拉"}]
        })

      {:ok, view, html} = live(conn, ~p"/my-name-card")
      assert html =~ "莎拉"

      view |> element("#lang-0 button[phx-click=remove_language]") |> render_click()

      refute render(view) =~ "莎拉"
    end
  end

  describe "share modal" do
    test "opens share modal for saved card", %{conn: conn} do
      {:ok, _} = NameCards.save_name_card(%{display_name: "Sarah"})
      {:ok, view, _html} = live(conn, ~p"/my-name-card")

      view |> element("#share-btn") |> render_click()

      assert has_element?(view, "#share-modal")
      assert has_element?(view, "#copy-link-btn")
      assert render(view) =~ "/card/"
    end

    test "closes share modal", %{conn: conn} do
      {:ok, _} = NameCards.save_name_card(%{display_name: "Sarah"})
      {:ok, view, _html} = live(conn, ~p"/my-name-card")

      view |> element("#share-btn") |> render_click()
      assert has_element?(view, "#share-modal")

      view |> element("button[aria-label='Close share dialog']") |> render_click()
      refute has_element?(view, "#share-modal")
    end
  end

  describe "delete card" do
    test "deletes existing card", %{conn: conn} do
      {:ok, _} = NameCards.save_name_card(%{display_name: "Sarah"})
      {:ok, view, _html} = live(conn, ~p"/my-name-card")

      assert has_element?(view, "#delete-card-btn")

      view |> element("#delete-card-btn") |> render_click()

      assert render(view) =~ "Name card deleted"
      refute has_element?(view, "#share-btn")
      refute has_element?(view, "#delete-card-btn")

      assert NameCards.get_name_card() == nil
    end
  end
end
