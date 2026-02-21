if Code.ensure_loaded?(Wallaby.Feature) and Code.ensure_loaded?(Wallaby.Query) and
     Code.ensure_loaded?(Wallaby.Browser) do
  defmodule ZonelyWeb.FeatureCase do
    @moduledoc """
    This module defines the test case to be used by feature tests that require browser automation.
    """

    use ExUnit.CaseTemplate

    using do
      quote do
        use Wallaby.Feature

        import Wallaby.Query,
          only: [css: 1, css: 2, text_field: 1, button: 1, link: 1, select: 1, checkbox: 1]

        import ZonelyWeb.FeatureCase

        alias ZonelyWeb.Endpoint
        alias Zonely.Repo

        @endpoint ZonelyWeb.Endpoint
      end
    end

    import ExUnit.Assertions
    import Wallaby.Query, only: [css: 1, css: 2]

    import Wallaby.Browser,
      only: [
        has_text?: 2,
        click: 2,
        current_path: 1,
        has?: 2,
        execute_script: 2,
        assert_text: 2
      ]

    def refute_text(session, text) do
      refute has_text?(session, text)
      session
    end

    def create_test_user(attrs \\ %{}) do
      default_attrs = %{
        name: "Test User",
        role: "Software Engineer",
        country: "US",
        timezone: "America/New_York",
        native_language: "en-US",
        name_native: nil,
        pronouns: "they/them",
        latitude: Decimal.new("40.7128"),
        longitude: Decimal.new("-74.0060"),
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00]
      }

      attrs = Map.merge(default_attrs, attrs)

      user_attrs = %{
        name: attrs.name,
        role: attrs.role,
        country: attrs.country,
        timezone: attrs.timezone,
        native_language: attrs.native_language,
        name_native: attrs.name_native,
        pronouns: attrs.pronouns,
        latitude: attrs.latitude,
        longitude: attrs.longitude,
        work_start: attrs.work_start,
        work_end: attrs.work_end
      }

      Zonely.Repo.insert!(struct(Zonely.Accounts.User, user_attrs))
    end

    def wait_for_liveview(session) do
      assert session |> has?(css("main"))
      assert session |> has?(css("body:not(.phx-loading)"))
      session
    end

    def wait_for_map_loaded(session) do
      assert session |> has?(css("#map-container[data-users]"))
      result = session |> execute_script("return window.teamUsers && window.teamUsers.length > 0")
      assert result
      session
    end

    def mock_audio_support(session) do
      session
      |> execute_script("""
        window.speechSynthesis = {
          getVoices: () => [
            { name: 'Test Voice', lang: 'en-US', localService: true }
          ],
          speak: (utterance) => {
            setTimeout(() => utterance.onend && utterance.onend(), 100);
          },
          cancel: () => {},
          onvoiceschanged: null
        };

        window.Audio = function(src) {
          this.play = () => Promise.resolve();
          this.pause = () => {};
          this.currentTime = 0;
          this.onended = null;
          setTimeout(() => this.onended && this.onended(), 100);
          return this;
        };
      """)
    end

    def drag_time_scrubber(session, start_fraction, end_fraction) do
      session
      |> execute_script("""
        const scrubber = document.getElementById('time-scrubber');
        const rect = scrubber.getBoundingClientRect();
        const startX = rect.left + (rect.width * #{start_fraction});
        const endX = rect.left + (rect.width * #{end_fraction});
        const mouseDown = new MouseEvent('mousedown', { clientX: startX, clientY: rect.top + rect.height / 2, bubbles: true });
        const mouseMove = new MouseEvent('mousemove', { clientX: endX, clientY: rect.top + rect.height / 2, bubbles: true });
        const mouseUp = new MouseEvent('mouseup', { clientX: endX, clientY: rect.top + rect.height / 2, bubbles: true });
        scrubber.dispatchEvent(mouseDown);
        document.dispatchEvent(mouseMove);
        document.dispatchEvent(mouseUp);
        return true;
      """)
    end

    def testid(id), do: css("[data-testid='#{id}']")

    def assert_path(session, expected_path),
      do:
        (
          assert current_path(session) == expected_path
          session
        )

    def select(session, query, option: value),
      do: session |> click(query) |> click(css("option", text: value))

    def check(session, query), do: session |> click(query)
  end
else
  defmodule ZonelyWeb.FeatureCase do
    @moduledoc false
    use ExUnit.CaseTemplate

    using do
      quote do
        use ExUnit.Case
        @moduletag :skip

        import ZonelyWeb.FeatureCase,
          only: [
            feature: 2,
            feature: 3,
            css: 1,
            css: 2,
            has?: 2,
            execute_script: 2,
            click: 2,
            current_path: 1,
            testid: 1,
            select: 2,
            check: 2,
            visit: 2,
            assert_text: 2,
            refute_text: 2,
            assert_has: 2,
            assert_path: 2,
            wait_for_liveview: 1,
            wait_for_map_loaded: 1,
            mock_audio_support: 1,
            drag_time_scrubber: 3,
            create_test_user: 1
          ]
      end
    end

    # Define a no-op Wallaby-like feature macro so files compile without Wallaby.
    defmacro feature(description, _meta, do: _block) do
      quote do
        @tag :skip
        test unquote(description) do
          assert true
        end
      end
    end

    defmacro feature(description, do: _block) do
      quote do
        @tag :skip
        test unquote(description) do
          assert true
        end
      end
    end

    # --- Stub helpers so feature test modules compile without Wallaby ---
    def css(selector), do: {:css, selector}
    def css(selector, _opts), do: {:css, selector}
    def has?(_session, _query), do: true
    def execute_script(_session, _js), do: true
    def click(session, _query), do: session
    def current_path(_session), do: "/"
    def testid(id), do: css("[data-testid='#{id}']")
    def select(session, _query), do: session
    def check(session, _query), do: session
    def visit(session, _path), do: session
    def assert_text(session, _text), do: session
    def refute_text(session, _text), do: session
    def assert_has(session, _query), do: session
    def assert_path(session, _path), do: session
    def wait_for_liveview(session), do: session
    def wait_for_map_loaded(session), do: session
    def mock_audio_support(session), do: session
    def drag_time_scrubber(session, _a, _b), do: session

    def create_test_user(attrs \\ %{}) do
      default_attrs = %{
        id: Ecto.UUID.generate(),
        name: "Test User",
        role: "Software Engineer",
        country: "US",
        timezone: "America/New_York",
        native_language: "en-US",
        name_native: nil,
        pronouns: "they/them",
        latitude: Decimal.new("0"),
        longitude: Decimal.new("0"),
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00]
      }

      Map.merge(default_attrs, attrs)
    end
  end
end
