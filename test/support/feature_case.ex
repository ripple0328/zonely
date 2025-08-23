defmodule ZonelyWeb.FeatureCase do
  @moduledoc """
  This module defines the test case to be used by feature tests that require browser automation.

  Such tests rely on `Wallaby` to drive the browser and interact with the application as a real user would.
  """

  use ExUnit.CaseTemplate

  import Wallaby.Query, only: [css: 1, css: 2]
  import Wallaby.Browser, only: [has_text?: 2, click: 2, current_path: 1, has?: 2, execute_script: 2]

  using do
    quote do
      use Wallaby.Feature

      import Wallaby.Query, only: [css: 1, css: 2, text_field: 1, button: 1, link: 1, select: 1, checkbox: 1]
      import ZonelyWeb.FeatureCase

      alias ZonelyWeb.Endpoint
      alias Zonely.Repo

      # The default endpoint for testing
      @endpoint ZonelyWeb.Endpoint
    end
  end

  # Wallaby.Feature already checks out repos & starts sessions with metadata.

  @doc """
  Helper to create test users with all required fields.
  """
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

    # Note: Skip setting ID as User schema uses :binary_id (UUID)

    Zonely.Repo.insert!(struct(Zonely.Accounts.User, user_attrs))
  end

  @doc """
  Helper to wait for LiveView to be mounted and ready.
  """
  def wait_for_liveview(session) do
    assert session |> has?(css("main"))
    # Wait until the page is not in loading state
    assert session |> has?(css("body:not(.phx-loading)"))
    session
  end

  @doc """
  Helper to wait for map to be loaded with user data.
  """
  def wait_for_map_loaded(session) do
    assert session |> has?(css("#map-container[data-users]"))
    result = session |> execute_script("return window.teamUsers && window.teamUsers.length > 0")
    assert result
    session
  end

  @doc """
  Helper to simulate audio events for testing pronunciation features.
  """
  def mock_audio_support(session) do
    session
    |> execute_script("""
      window.speechSynthesis = {
        getVoices: () => [
          { name: 'Test Voice', lang: 'en-US', localService: true }
        ],
        speak: (utterance) => {
          console.log('Mock TTS:', utterance.text, utterance.lang);
          setTimeout(() => utterance.onend && utterance.onend(), 100);
        },
        cancel: () => console.log('Mock TTS cancelled'),
        onvoiceschanged: null
      };

      window.Audio = function(src) {
        console.log('Mock Audio:', src);
        this.play = () => Promise.resolve();
        this.pause = () => {};
        this.currentTime = 0;
        this.onended = null;
        setTimeout(() => this.onended && this.onended(), 100);
        return this;
      };
    """)
  end

  @doc """
  Helper to simulate time scrubber interactions.
  """
  def drag_time_scrubber(session, start_fraction, end_fraction) do
    session
    |> execute_script("""
      const scrubber = document.getElementById('time-scrubber');
      const rect = scrubber.getBoundingClientRect();
      const startX = rect.left + (rect.width * #{start_fraction});
      const endX = rect.left + (rect.width * #{end_fraction});

      // Simulate mouse events for drag
      const mouseDown = new MouseEvent('mousedown', {
        clientX: startX,
        clientY: rect.top + rect.height / 2,
        bubbles: true
      });

      const mouseMove = new MouseEvent('mousemove', {
        clientX: endX,
        clientY: rect.top + rect.height / 2,
        bubbles: true
      });

      const mouseUp = new MouseEvent('mouseup', {
        clientX: endX,
        clientY: rect.top + rect.height / 2,
        bubbles: true
      });

      scrubber.dispatchEvent(mouseDown);
      document.dispatchEvent(mouseMove);
      document.dispatchEvent(mouseUp);

      return true;
    """)
  end

  @doc """
  Helper to create CSS selector for data-testid attributes.
  """
  def testid(id) do
    css("[data-testid='#{id}']")
  end

  @doc """
  Helper to assert current path matches expected path.
  """
  def assert_path(session, expected_path) do
    assert current_path(session) == expected_path
    session
  end

  @doc """
  Helper to assert text is NOT present on the page.
  """
  def refute_text(session, text) do
    refute session |> has_text?(text)
    session
  end

  @doc """
  Helper to select an option from a dropdown.
  """
  def select(session, query, option: value) do
    session
    |> click(query)
    |> click(css("option", text: value))
  end

  @doc """
  Helper to check a checkbox.
  """
  def check(session, query) do
    session
    |> click(query)
  end
end
