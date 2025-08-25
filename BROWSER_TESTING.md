# Browser Testing with Wallaby

This project uses [Wallaby](https://hexdocs.pm/wallaby/) for browser-based feature testing. Wallaby provides real browser automation to test user journeys and interactions in Phoenix LiveView applications.

## Quick Start

```bash
# Run all browser tests (headless)
mix test.browser

# Run tests with visible browser window
mix test.browser --show

# Run specific test file
mix test.browser test/zonely_web/features/team_map_test.exs

# Run with debugging (visible browser + stop on first failure)
mix test.browser --show --max-failures=1

# Run with verbose output to see the exact command being executed
mix test.browser --verbose --max-failures=1
```

## Setup Requirements

### Prerequisites
- **Chrome Browser**: Required for browser automation
- **ChromeDriver**: Managed via mise (see `.mise.toml`)
- **PostgreSQL**: For test database

### Installation
```bash
# Install all project dependencies including chromedriver
mise install

# Trust the mise configuration (if prompted)
mise trust
```

## Test Structure

Browser tests are located in `test/zonely_web/features/` and cover:

- **Team Map** (`team_map_test.exs`) - Map interactions, user profiles, audio features
- **Directory** (`directory_test.exs`) - User directory, search, filtering
- **Work Hours** (`work_hours_test.exs`) - Time selection, overlaps, scheduling  
- **Holidays** (`holidays_test.exs`) - Country-based holidays, team impact

## Custom Mix Task: `mix test.browser`

Instead of remembering complex environment variables, use the custom mix task:

```bash
mix test.browser [OPTIONS] [FILES]
```

### Options

| Flag | Description |
|------|-------------|
| `--show` | Show browser window (non-headless mode) |
| `--max-failures=N` | Stop after N test failures |
| `--verbose` | Show detailed command output |
| `--seed=N` | Set random seed for test execution order |

### Examples

```bash
# Basic usage - run all feature tests
mix test.browser

# Debug a failing test with visible browser
mix test.browser --show --max-failures=1

# Run only map-related tests
mix test.browser test/zonely_web/features/team_map_test.exs

# Run tests with specific seed for reproducibility
mix test.browser --seed=12345

# Verbose output to see what's being executed
mix test.browser --verbose
```

## Manual Commands (Alternative)

If you prefer to run tests manually without the mix task:

```bash
# All feature tests (headless)
WALLABY_ENABLE_SERVER=true mix test --only feature

# With visible browser
HEADLESS=false WALLABY_ENABLE_SERVER=true mix test --only feature

# Specific test file
WALLABY_ENABLE_SERVER=true mix test test/zonely_web/features/team_map_test.exs --only feature

# Single test with browser visible
HEADLESS=false WALLABY_ENABLE_SERVER=true mix test test/zonely_web/features/team_map_test.exs --only feature --max-failures=1
```

## Test Configuration

Browser tests are configured in `config/test.exs`:

```elixir
config :wallaby,
  driver: Wallaby.Chrome,
  base_url: "http://localhost:4002",
  chrome: [
    binary: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    headless: System.get_env("HEADLESS", "true") == "true"
  ],
  chromedriver: [
    path: "/path/to/your/chromedriver"
  ]
```

## Writing Browser Tests

Browser tests use the `ZonelyWeb.FeatureCase` which provides:

- **Database isolation** with Ecto sandbox
- **Browser session management** with Wallaby
- **Helper functions** for common operations
- **LiveView integration** for real-time testing

### Example Test Structure

```elixir
defmodule ZonelyWeb.Features.MyFeatureTest do
  use ZonelyWeb.FeatureCase, async: false

  @moduletag :feature

  describe "My Feature" do
    setup do
      user = create_test_user(%{name: "Test User", country: "US"})
      %{user: user}
    end

    test "user can interact with feature", %{session: session} do
      session
      |> visit("/my-page")
      |> wait_for_liveview()
      |> click(testid("my-button"))
      |> assert_text("Expected result")
      |> assert_path("/expected-path")
    end
  end
end
```

### Helper Functions Available

- `create_test_user(attrs)` - Create test users with required fields
- `wait_for_liveview(session)` - Wait for LiveView to mount
- `wait_for_map_loaded(session)` - Wait for map data to load
- `testid(id)` - CSS selector for `data-testid` attributes
- `assert_path(session, path)` - Assert current URL path
- `mock_audio_support(session)` - Mock browser audio APIs for testing

## Test Data

Tests use the `create_test_user/1` helper which creates users with all required fields:

```elixir
user = create_test_user(%{
  name: "Alice Johnson",
  country: "US", 
  timezone: "America/New_York",
  role: "Frontend Developer"
  # latitude, longitude, work hours are auto-generated
})
```

## Troubleshooting

### ChromeDriver Issues
```bash
# Verify chromedriver is installed and accessible
mise install chromedriver
which chromedriver
chromedriver --version
```

### Phoenix Server Issues
```bash
# Ensure test database is created and migrated
mix ecto.create MIX_ENV=test
mix ecto.migrate MIX_ENV=test
```

### Test Failures
```bash
# Run with visible browser to debug
mix test.browser --show --max-failures=1

# Check server logs in test output for errors
mix test.browser --verbose
```

### Common Issues

1. **"ChromeDriver not found"** - Run `mise install` to install dependencies
2. **"Connection refused"** - Phoenix test server failed to start, check database connection
3. **"Element not found"** - Check that UI elements have correct `data-testid` attributes
4. **Timeout errors** - Increase timeout or check for JavaScript errors in browser console

## CI/CD Integration

For continuous integration, browser tests can run in headless mode:

```bash
# CI-friendly command (always headless)
WALLABY_ENABLE_SERVER=true mix test --only feature
```

Add to your CI pipeline with proper Chrome/ChromeDriver setup for the CI environment.

## Performance Notes

- Browser tests are slower than unit tests (typically 5-10s per test)
- Tests run with `async: false` to prevent database conflicts
- Use `--max-failures=1` during development to fail fast
- Consider running browser tests separately from unit tests in CI

## Browser Test Coverage

Current test coverage includes:

- ✅ **Navigation** - Page routing and menu interactions
- ✅ **User Interactions** - Clicking, form filling, modal operations  
- ✅ **LiveView Features** - Real-time updates, pubsub events
- ✅ **Audio Features** - Pronunciation playback (mocked)
- ✅ **Map Interactions** - User markers, time scrubbing
- ✅ **Search & Filtering** - Directory search, country filters
- ✅ **Working Hours** - Time selection, overlap calculations
- ✅ **Responsive Design** - Mobile and desktop layouts

The test suite provides comprehensive coverage of user journeys across the entire application.