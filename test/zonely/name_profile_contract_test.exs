defmodule Zonely.NameProfileContractTest do
  use ExUnit.Case, async: true

  alias Zonely.Accounts.User
  alias Zonely.NameProfileContract

  describe "from_user/1" do
    test "maps a user to canonical SayMyName lang/text variants" do
      user = %User{
        id: "user-1",
        name: " Qingbo ",
        name_native: " 清波 ",
        native_language: "zh-cn",
        country: "CN"
      }

      assert NameProfileContract.from_user(user) == %{
               "id" => "user-1",
               "display_name" => "Qingbo",
               "variants" => [
                 %{"lang" => "en-US", "text" => "Qingbo"},
                 %{"lang" => "zh-CN", "text" => "清波"}
               ]
             }
    end

    test "omits blank native variants" do
      user = %User{
        id: "user-2",
        name: "River",
        name_native: " ",
        native_language: "ja-JP",
        country: "JP"
      }

      assert NameProfileContract.from_user(user)["variants"] == [
               %{"lang" => "en-US", "text" => "River"}
             ]
    end

    test "omits duplicate native variants" do
      user = %User{
        id: "user-3",
        name: "Alice Chen",
        name_native: "Alice Chen",
        native_language: "en-US",
        country: "US"
      }

      assert NameProfileContract.from_user(user)["variants"] == [
               %{"lang" => "en-US", "text" => "Alice Chen"}
             ]
    end

    test "canonicalizes short native language codes with country locale when possible" do
      user = %User{
        id: "user-4",
        name: "Yuki Tanaka",
        name_native: "田中雪",
        native_language: "ja",
        country: "JP"
      }

      assert NameProfileContract.from_user(user)["variants"] == [
               %{"lang" => "en-US", "text" => "Yuki Tanaka"},
               %{"lang" => "ja-JP", "text" => "田中雪"}
             ]
    end

    test "falls back to country locale for invalid native language values" do
      user = %User{
        id: "user-5",
        name: "Maria Garcia",
        name_native: "María García",
        native_language: "Spanish",
        country: "ES"
      }

      assert NameProfileContract.from_user(user)["variants"] == [
               %{"lang" => "en-US", "text" => "Maria Garcia"},
               %{"lang" => "es-ES", "text" => "María García"}
             ]
    end

    test "canonicalizes regional native languages to SayMyName-supported catalog codes" do
      user = %User{
        id: "user-6",
        name: "Ahmed Hassan",
        name_native: "أحمد حسن",
        native_language: "ar-EG",
        country: "EG"
      }

      assert NameProfileContract.from_user(user)["variants"] == [
               %{"lang" => "en-US", "text" => "Ahmed Hassan"},
               %{"lang" => "ar-SA", "text" => "أحمد حسن"}
             ]
    end

    test "canonicalizes country-derived native languages to SayMyName-supported catalog codes" do
      user = %User{
        id: "user-7",
        name: "Ahmed Hassan",
        name_native: "أحمد حسن",
        native_language: nil,
        country: "EG"
      }

      assert NameProfileContract.from_user(user)["variants"] == [
               %{"lang" => "en-US", "text" => "Ahmed Hassan"},
               %{"lang" => "ar-SA", "text" => "أحمد حسن"}
             ]
    end

    test "omits native variants when SayMyName has no supported language match" do
      user = %User{
        id: "user-8",
        name: "Bjorn Eriksson",
        name_native: "Björn Eriksson",
        native_language: "sv-SE",
        country: "SE"
      }

      assert NameProfileContract.from_user(user)["variants"] == [
               %{"lang" => "en-US", "text" => "Bjorn Eriksson"}
             ]
    end
  end

  describe "from_users/2" do
    test "builds a reusable name-list payload" do
      users = [
        %User{id: "user-1", name: "Alice", country: "US"},
        %User{
          id: "user-2",
          name: "Ming",
          name_native: "王明",
          native_language: "zh-CN",
          country: "CN"
        }
      ]

      payload = NameProfileContract.from_users("Zonely Team", users)

      assert payload["name"] == "Zonely Team"
      assert Enum.map(payload["entries"], & &1["id"]) == ["user-1", "user-2"]

      assert List.last(payload["entries"])["variants"] == [
               %{"lang" => "en-US", "text" => "Ming"},
               %{"lang" => "zh-CN", "text" => "王明"}
             ]
    end
  end
end
