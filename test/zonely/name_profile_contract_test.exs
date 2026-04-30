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

  describe "parse/1" do
    test "accepts and projects a canonical shared_profile_v1 card payload" do
      payload = %{
        "version" => "shared_profile_v1",
        "person" => %{
          "id" => "say-1",
          "display_name" => "San Zhang",
          "pronouns" => "he/him",
          "role" => "Engineering",
          "name_variants" => [
            %{
              "lang" => "en-US",
              "text" => "San Zhang",
              "script" => "Latn",
              "pronunciation" => %{
                "audio_url" => "https://saymyname.example/audio/san.mp3",
                "source_kind" => "recorded"
              }
            },
            %{"lang" => "zh-CN", "text" => "张三", "script" => "Hans"}
          ]
        },
        "location" => %{
          "country" => "US",
          "label" => "San Francisco",
          "latitude" => 37.7749,
          "longitude" => -122.4194
        },
        "availability" => %{
          "timezone" => "America/Los_Angeles",
          "work_start" => "09:00",
          "work_end" => "17:00"
        }
      }

      assert {:ok, projection} = NameProfileContract.parse(payload)

      assert projection == %{
               kind: :person,
               version: "shared_profile_v1",
               person: %{
                 "id" => "say-1",
                 "display_name" => "San Zhang",
                 "pronouns" => "he/him",
                 "role" => "Engineering",
                 "name_variants" => [
                   %{
                     "lang" => "en-US",
                     "text" => "San Zhang",
                     "script" => "Latn",
                     "pronunciation" => %{
                       "audio_url" => "https://saymyname.example/audio/san.mp3",
                       "source_kind" => "recorded"
                     }
                   },
                   %{"lang" => "zh-CN", "text" => "张三", "script" => "Hans"}
                 ]
               },
               location: %{
                 "country" => "US",
                 "label" => "San Francisco",
                 "latitude" => 37.7749,
                 "longitude" => -122.4194
               },
               availability: %{
                 "timezone" => "America/Los_Angeles",
                 "work_start" => "09:00",
                 "work_end" => "17:00"
               }
             }
    end

    test "accepts and projects a canonical team/list payload" do
      payload = %{
        "version" => "shared_profile_v1",
        "team" => %{"id" => "team-1", "name" => "Zonely Team"},
        "memberships" => [
          %{
            "person" => %{"display_name" => "Avery Stone"},
            "role" => "Design",
            "location" => %{"country" => "GB", "label" => "London"},
            "availability" => %{
              "timezone" => "Europe/London",
              "work_start" => "08:30",
              "work_end" => "16:30"
            }
          },
          %{
            "person" => %{
              "display_name" => "Mina Park",
              "name_variants" => [%{"lang" => "ko-KR", "text" => "박민아"}]
            },
            "location" => %{"country" => "KR", "label" => "Seoul"}
          }
        ]
      }

      assert {:ok, projection} = NameProfileContract.parse(payload)

      assert projection.kind == :team
      assert projection.team == %{"id" => "team-1", "name" => "Zonely Team"}
      assert length(projection.memberships) == 2
      assert hd(projection.memberships)["role"] == "Design"

      assert get_in(List.last(projection.memberships), ["person", "name_variants"]) == [
               %{"lang" => "ko-KR", "text" => "박민아"}
             ]
    end

    test "rejects unsupported versions and unrelated payload shapes" do
      assert {:error, :unsupported_version} =
               NameProfileContract.parse(%{"version" => "shared_profile_v2", "person" => %{}})

      assert {:error, :unsupported_shape} =
               NameProfileContract.parse(%{"version" => "shared_profile_v1", "people" => []})
    end

    test "rejects empty team lists and memberships missing person identity" do
      assert {:error, :empty_memberships} =
               NameProfileContract.parse(%{
                 "version" => "shared_profile_v1",
                 "team" => %{"name" => "Empty"},
                 "memberships" => []
               })

      assert {:error, {:invalid_membership, 0, :missing_display_name}} =
               NameProfileContract.parse(%{
                 "version" => "shared_profile_v1",
                 "team" => %{"name" => "Invalid"},
                 "memberships" => [%{"person" => %{"name_variants" => []}}]
               })
    end

    test "preserves missing Zonely-owned fields without defaults and does not infer coordinates" do
      payload = %{
        "version" => "shared_profile_v1",
        "person" => %{"display_name" => "Lina Torres", "pronouns" => "she/her"},
        "location" => %{"country" => "PT", "label" => "Lisbon"}
      }

      assert {:ok, projection} = NameProfileContract.parse(payload)

      refute Map.has_key?(projection, :availability)
      assert projection.location == %{"country" => "PT", "label" => "Lisbon"}
      refute Map.has_key?(projection.location, "latitude")
      refute Map.has_key?(projection.location, "longitude")
    end

    test "rejects partial coordinates, invalid timezone offsets, invalid work hours, and invalid variants" do
      assert {:error, {:invalid_location, :partial_coordinates}} =
               NameProfileContract.parse(%{
                 "version" => "shared_profile_v1",
                 "person" => %{"display_name" => "Kai"},
                 "location" => %{"latitude" => 35.6762}
               })

      assert {:error, {:invalid_availability, :invalid_timezone}} =
               NameProfileContract.parse(%{
                 "version" => "shared_profile_v1",
                 "person" => %{"display_name" => "Kai"},
                 "availability" => %{"timezone" => "+08:00"}
               })

      assert {:error, {:invalid_availability, :invalid_work_start}} =
               NameProfileContract.parse(%{
                 "version" => "shared_profile_v1",
                 "person" => %{"display_name" => "Kai"},
                 "availability" => %{"work_start" => "9am"}
               })

      assert {:error, {:invalid_person, :invalid_name_variants}} =
               NameProfileContract.parse(%{
                 "version" => "shared_profile_v1",
                 "person" => %{
                   "display_name" => "Kai",
                   "name_variants" => [%{"lang" => "", "text" => "Kai"}]
                 }
               })
    end

    test "normalizes wrapped share-link payloads only at explicit payload boundaries" do
      payload = %{
        "version" => "shared_profile_v1",
        "person" => %{"display_name" => "Rhea Patel"}
      }

      assert {:ok, %{kind: :person, person: %{"display_name" => "Rhea Patel"}}} =
               NameProfileContract.parse(%{"payload" => payload})

      assert {:ok, %{kind: :person, person: %{"display_name" => "Rhea Patel"}}} =
               NameProfileContract.parse(%{"data" => %{"payload" => payload}})

      assert {:error, :invalid_payload} =
               NameProfileContract.parse("https://example.test/share/abc")

      assert {:error, :invalid_payload} = NameProfileContract.parse(%{"payload" => "not-json"})
    end
  end
end
