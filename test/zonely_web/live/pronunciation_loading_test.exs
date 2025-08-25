defmodule ZonelyWeb.PronunciationLoadingTest do
  use ZonelyWeb.ComponentCase, async: true

  alias Zonely.Accounts.User

  describe "pronunciation buttons loading states" do
    test "render with normal state" do
      user = %User{
        id: "1",
        name: "John Doe",
        name_native: "جان دو",
        country: "US"
      }

      html =
        render_component_test(&ZonelyWeb.CoreComponents.pronunciation_buttons/1, %{
          user: user,
          loading_pronunciation: nil,
          playing_pronunciation: %{}
        })

      assert html =~ "data-testid=\"pronunciation-english\""
      assert html =~ "data-testid=\"pronunciation-native\""
      refute html =~ "animate-spin"
      refute html =~ "animate-pulse"
      # Should show play icons in normal state (SVG elements)
      assert html =~ "fill-rule=\"evenodd\""
      assert html =~ "path"
    end

    test "render English loading state" do
      user = %User{
        id: "1",
        name: "John Doe",
        name_native: "جان دو",
        country: "US"
      }

      html =
        render_component_test(&ZonelyWeb.CoreComponents.pronunciation_buttons/1, %{
          user: user,
          loading_pronunciation: "english",
          playing_pronunciation: %{}
        })

      assert html =~ "animate-spin"
      assert html =~ "animate-pulse bg-blue-100 text-blue-600"
      assert html =~ "Loading..."
    end

    test "render native loading state" do
      user = %User{
        id: "1",
        name: "John Doe",
        name_native: "جان دو",
        country: "US"
      }

      html =
        render_component_test(&ZonelyWeb.CoreComponents.pronunciation_buttons/1, %{
          user: user,
          loading_pronunciation: "native",
          playing_pronunciation: %{}
        })

      assert html =~ "animate-spin"
      assert html =~ "animate-pulse bg-blue-100 text-blue-600"
      assert html =~ "Loading..."
    end
  end

  describe "pronunciation buttons playing states" do
    test "render English playing state with real person audio" do
      user = %User{
        id: "1",
        name: "John Doe",
        country: "US"
      }

      html =
        render_component_test(&ZonelyWeb.CoreComponents.pronunciation_buttons/1, %{
          user: user,
          loading_pronunciation: nil,
          playing_pronunciation: %{"1" => %{type: "english", source: "audio"}}
        })

      assert html =~ "animate-pulse bg-green-100 text-green-600"
      assert html =~ "Real person voice"
      # Should show user icon for real person (SVG with user path)  
      assert html =~ "d=\"M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z\""
    end

    test "render English playing state with AI generated audio" do
      user = %User{
        id: "1",
        name: "John Doe",
        country: "US"
      }

      html =
        render_component_test(&ZonelyWeb.CoreComponents.pronunciation_buttons/1, %{
          user: user,
          loading_pronunciation: nil,
          playing_pronunciation: %{"1" => %{type: "english", source: "tts"}}
        })

      assert html =~ "animate-pulse bg-orange-100 text-orange-600"
      assert html =~ "AI synthesized pronunciation"
      # Should show robot icon for AI
      # Should not show user icon for AI
      refute html =~ "d=\"M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z\""
    end

    test "render native playing state with AI generated audio" do
      user = %User{
        id: "1",
        name: "John Doe",
        name_native: "جان دو",
        country: "US"
      }

      html =
        render_component_test(&ZonelyWeb.CoreComponents.pronunciation_buttons/1, %{
          user: user,
          loading_pronunciation: nil,
          playing_pronunciation: %{"1" => %{type: "native", source: "tts"}}
        })

      assert html =~ "animate-pulse bg-orange-100 text-orange-600"
      assert html =~ "AI synthesized pronunciation"
    end

    test "render native playing state with real person audio" do
      user = %User{
        id: "1",
        name: "John Doe",
        name_native: "جان دو",
        country: "US"
      }

      html =
        render_component_test(&ZonelyWeb.CoreComponents.pronunciation_buttons/1, %{
          user: user,
          loading_pronunciation: nil,
          playing_pronunciation: %{"1" => %{type: "native", source: "audio"}}
        })

      assert html =~ "animate-pulse bg-green-100 text-green-600"
      assert html =~ "Real person voice"
      # Should show user icon for real person (SVG with user path)
      assert html =~ "d=\"M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z\""
    end
  end
end
