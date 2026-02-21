defmodule Zonely.NameCardsTest do
  use Zonely.DataCase, async: true

  alias Zonely.NameCards
  alias Zonely.NameCards.NameCard

  # Clean up any stale data from previous test runs
  setup do
    Repo.delete_all(NameCard)
    :ok
  end

  describe "NameCard schema" do
    test "supported_languages/0 returns list of language tuples" do
      langs = NameCard.supported_languages()
      assert is_list(langs)
      assert length(langs) == 20

      # Verify structure
      for {code, label, flag} <- langs do
        assert is_binary(code)
        assert is_binary(label)
        assert is_binary(flag)
      end
    end

    test "language_label/1 returns flag and label for known code" do
      assert NameCard.language_label("en") =~ "English"
      assert NameCard.language_label("ja") =~ "Japanese"
    end

    test "language_label/1 returns code for unknown language" do
      assert NameCard.language_label("xx") == "xx"
    end

    test "language_flag/1 returns flag for known code" do
      assert NameCard.language_flag("zh-CN") == "🇨🇳"
      assert NameCard.language_flag("en") == "🇺🇸"
    end

    test "language_flag/1 returns globe for unknown code" do
      assert NameCard.language_flag("xx") == "🌐"
    end

    test "changeset requires display_name" do
      changeset = NameCard.changeset(%NameCard{}, %{})
      assert %{display_name: ["can't be blank"]} = errors_on(changeset)
    end

    test "changeset validates display_name length" do
      long_name = String.duplicate("a", 101)
      changeset = NameCard.changeset(%NameCard{}, %{display_name: long_name})
      assert %{display_name: [msg]} = errors_on(changeset)
      assert msg =~ "at most"
    end

    test "changeset validates pronouns max length" do
      long = String.duplicate("a", 51)
      changeset = NameCard.changeset(%NameCard{}, %{display_name: "Test", pronouns: long})
      assert %{pronouns: [_]} = errors_on(changeset)
    end

    test "changeset validates role max length" do
      long = String.duplicate("a", 101)
      changeset = NameCard.changeset(%NameCard{}, %{display_name: "Test", role: long})
      assert %{role: [_]} = errors_on(changeset)
    end

    test "changeset auto-generates share_token" do
      changeset = NameCard.changeset(%NameCard{}, %{display_name: "Test"})
      assert Ecto.Changeset.get_field(changeset, :share_token) != nil
    end

    test "changeset does not overwrite existing share_token" do
      card = %NameCard{share_token: "existing-token"}
      changeset = NameCard.changeset(card, %{display_name: "Test"})
      assert Ecto.Changeset.get_field(changeset, :share_token) == "existing-token"
    end

    test "changeset validates language_variants structure" do
      bad_variants = [%{"language" => "invalid", "name" => "Test"}]

      changeset =
        NameCard.changeset(%NameCard{}, %{
          display_name: "Test",
          language_variants: bad_variants
        })

      assert %{language_variants: ["contains invalid entries"]} = errors_on(changeset)
    end

    test "changeset accepts valid language_variants" do
      good_variants = [%{"language" => "zh-CN", "name" => "测试"}]

      changeset =
        NameCard.changeset(%NameCard{}, %{
          display_name: "Test",
          language_variants: good_variants
        })

      assert changeset.valid?
    end

    test "changeset rejects language_variants with empty name" do
      bad_variants = [%{"language" => "zh-CN", "name" => ""}]

      changeset =
        NameCard.changeset(%NameCard{}, %{
          display_name: "Test",
          language_variants: bad_variants
        })

      assert %{language_variants: ["contains invalid entries"]} = errors_on(changeset)
    end
  end

  describe "get_name_card/0" do
    test "returns nil when no card exists" do
      assert NameCards.get_name_card() == nil
    end

    test "returns the card when one exists" do
      {:ok, card} = NameCards.save_name_card(%{display_name: "Sarah Chen"})
      found = NameCards.get_name_card()
      assert found.id == card.id
      assert found.display_name == "Sarah Chen"
    end
  end

  describe "save_name_card/1" do
    test "creates a new card when none exists" do
      assert {:ok, card} =
               NameCards.save_name_card(%{
                 display_name: "Sarah Chen",
                 pronouns: "she/her",
                 role: "Designer"
               })

      assert card.display_name == "Sarah Chen"
      assert card.pronouns == "she/her"
      assert card.role == "Designer"
      assert card.share_token != nil
    end

    test "updates existing card" do
      {:ok, original} = NameCards.save_name_card(%{display_name: "Sarah"})
      {:ok, updated} = NameCards.save_name_card(%{display_name: "Sarah Chen"})

      assert updated.id == original.id
      assert updated.display_name == "Sarah Chen"
    end
  end

  describe "save_name_card/1 returns error on invalid data" do
    test "returns error changeset for missing display_name" do
      assert {:error, changeset} = NameCards.save_name_card(%{})
      assert %{display_name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "get_name_card_by_token/1" do
    test "returns card for valid public token" do
      {:ok, card} = NameCards.save_name_card(%{display_name: "Sarah", is_public: true})
      found = NameCards.get_name_card_by_token(card.share_token)
      assert found.id == card.id
    end

    test "returns nil for non-public card" do
      {:ok, card} = NameCards.save_name_card(%{display_name: "Sarah", is_public: false})
      assert NameCards.get_name_card_by_token(card.share_token) == nil
    end

    test "returns nil for unknown token" do
      assert NameCards.get_name_card_by_token("nonexistent") == nil
    end

    test "returns nil for nil token" do
      assert NameCards.get_name_card_by_token(nil) == nil
    end
  end

  describe "delete_name_card/1" do
    test "deletes the card" do
      {:ok, card} = NameCards.save_name_card(%{display_name: "Sarah"})
      assert {:ok, _} = NameCards.delete_name_card(card)
      assert NameCards.get_name_card() == nil
    end
  end

  describe "regenerate_share_token/1" do
    test "changes the share token" do
      {:ok, card} = NameCards.save_name_card(%{display_name: "Sarah"})
      old_token = card.share_token
      {:ok, updated} = NameCards.regenerate_share_token(card)
      assert updated.share_token != old_token
    end
  end

  describe "change_name_card/2" do
    test "returns a changeset" do
      changeset = NameCards.change_name_card(%NameCard{}, %{display_name: "Test"})
      assert %Ecto.Changeset{} = changeset
    end
  end
end
