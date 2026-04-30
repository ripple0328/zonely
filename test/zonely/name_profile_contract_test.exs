defmodule Zonely.NameProfileContractTest do
  use ExUnit.Case, async: true

  alias Zonely.Accounts.Person
  alias Zonely.NameProfileContract

  describe "from_person/1" do
    test "maps a person to the canonical shared profile shape" do
      person = %Person{
        id: "person-1",
        name: " Qingbo ",
        pronouns: "he/him",
        role: "Engineering",
        name_native: " 清波 ",
        native_language: "zh-cn",
        country: "CN",
        timezone: "Asia/Shanghai",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00],
        latitude: Decimal.new("31.23040000"),
        longitude: Decimal.new("121.47370000")
      }

      assert NameProfileContract.from_person(person) == %{
               "version" => "shared_profile_v1",
               "person" => %{
                 "id" => "person-1",
                 "display_name" => "Qingbo",
                 "pronouns" => "he/him",
                 "role" => "Engineering",
                 "name_variants" => [
                   %{"lang" => "en-US", "text" => "Qingbo"},
                   %{"lang" => "zh-CN", "text" => "清波"}
                 ]
               },
               "location" => %{
                 "country" => "CN",
                 "latitude" => 31.2304,
                 "longitude" => 121.4737
               },
               "availability" => %{
                 "timezone" => "Asia/Shanghai",
                 "work_start" => "09:00:00",
                 "work_end" => "17:00:00"
               }
             }
    end

    test "prefers persisted name_variants when present" do
      person = %Person{
        id: "person-2",
        name: "River",
        name_variants: [
          %{"lang" => "en-US", "text" => "River"},
          %{"lang" => "ja-JP", "text" => "川"}
        ],
        country: "JP"
      }

      assert get_in(NameProfileContract.from_person(person), ["person", "name_variants"]) == [
               %{"lang" => "en-US", "text" => "River"},
               %{"lang" => "ja-JP", "text" => "川"}
             ]
    end

    test "omits blank native variants" do
      person = %Person{
        id: "person-3",
        name: "River",
        name_native: " ",
        native_language: "ja-JP",
        country: "JP"
      }

      assert NameProfileContract.variants_for(person) == [
               %{"lang" => "en-US", "text" => "River"}
             ]
    end

    test "omits duplicate native variants" do
      person = %Person{
        id: "person-4",
        name: "Alice Chen",
        name_native: "Alice Chen",
        native_language: "en-US",
        country: "US"
      }

      assert NameProfileContract.variants_for(person) == [
               %{"lang" => "en-US", "text" => "Alice Chen"}
             ]
    end

    test "canonicalizes native languages to SayMyName-supported catalog codes" do
      person = %Person{
        id: "person-5",
        name: "Ahmed Hassan",
        name_native: "أحمد حسن",
        native_language: "ar-EG",
        country: "EG"
      }

      assert NameProfileContract.variants_for(person) == [
               %{"lang" => "en-US", "text" => "Ahmed Hassan"},
               %{"lang" => "ar-SA", "text" => "أحمد حسن"}
             ]
    end

    test "omits native variants when SayMyName has no supported language match" do
      person = %Person{
        id: "person-6",
        name: "Bjorn Eriksson",
        name_native: "Björn Eriksson",
        native_language: "sv-SE",
        country: "SE"
      }

      assert NameProfileContract.variants_for(person) == [
               %{"lang" => "en-US", "text" => "Bjorn Eriksson"}
             ]
    end
  end

  describe "from_team/2" do
    test "builds a shared team profile payload" do
      people = [
        %Person{id: "person-1", name: "Alice", role: "Design", country: "US"},
        %Person{
          id: "person-2",
          name: "Ming",
          role: "Engineering",
          name_native: "王明",
          native_language: "zh-CN",
          country: "CN"
        }
      ]

      payload = NameProfileContract.from_team("Zonely Team", people)

      assert payload["version"] == "shared_profile_v1"
      assert payload["team"] == %{"name" => "Zonely Team"}

      assert Enum.map(payload["memberships"], &get_in(&1, ["person", "id"])) == [
               "person-1",
               "person-2"
             ]

      assert Enum.map(payload["memberships"], & &1["role"]) == ["Design", "Engineering"]

      assert get_in(List.last(payload["memberships"]), ["person", "name_variants"]) == [
               %{"lang" => "en-US", "text" => "Ming"},
               %{"lang" => "zh-CN", "text" => "王明"}
             ]
    end
  end
end
