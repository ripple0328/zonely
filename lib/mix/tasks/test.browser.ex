defmodule Mix.Tasks.Test.Browser do
  @moduledoc """
  Runs browser-based feature tests using Wallaby.

  This task provides a convenient way to run Wallaby browser tests without
  remembering all the required environment variables and flags.

  ## Examples

      # Run all feature tests (headless)
      mix test.browser

      # Run all feature tests with visible browser
      mix test.browser --show

      # Run specific test file
      mix test.browser test/zonely_web/features/team_map_test.exs

      # Run single test with browser visible and stop on first failure
      mix test.browser --show --max-failures=1

      # Run tests matching a pattern
      mix test.browser --grep "user can navigate"

  ## Options

    * `--show` - Run tests in non-headless mode (shows browser window)
    * `--max-failures=N` - Stop after N failures
    * `--grep=PATTERN` - Only run tests matching the pattern
    * `--seed=N` - Set random seed for test order
    * `--verbose` - Show detailed output

  """

  use Mix.Task

  @switches [
    show: :boolean,
    max_failures: :integer,
    grep: :string,
    seed: :integer,
    verbose: :boolean,
    help: :boolean
  ]

  def run(args) do
    {opts, files, _} = OptionParser.parse(args, switches: @switches)

    if opts[:help] do
      Mix.shell().info(@moduledoc)
    else
      # Build environment variables
      env_vars = [
        {"MIX_ENV", "test"},
        {"WALLABY_ENABLE_SERVER", "true"}
      ]

      env_vars = if opts[:show] do
        env_vars ++ [{"HEADLESS", "false"}]
      else
        env_vars ++ [{"HEADLESS", "true"}]
      end

      # Build test command arguments
      test_args = ["test", "--only", "feature"]

      # Add file paths if specified
      test_args = if Enum.empty?(files) do
        test_args ++ ["test/zonely_web/features/"]
      else
        test_args ++ files
      end

      # Add optional flags
      test_args = if opts[:max_failures] do
        test_args ++ ["--max-failures", to_string(opts[:max_failures])]
      else
        test_args
      end

      test_args = if opts[:seed] do
        test_args ++ ["--seed", to_string(opts[:seed])]
      else
        test_args
      end

      # Show what we're about to run
      if opts[:verbose] do
        Mix.shell().info("Running: mix #{Enum.join(test_args, " ")}")
        Mix.shell().info("Environment: #{inspect(env_vars)}")
      end

      # Ensure DB is ready and assets are built for LiveView pages before tests
      Mix.Task.run("ecto.create", ["--quiet"])
      Mix.Task.run("ecto.migrate", ["--quiet"])
      Mix.Task.run("assets.build", [])

      # Use System.cmd to run the command with proper environment
      {_output, exit_code} = System.cmd(
        "mix",
        test_args,
        env: env_vars,
        into: IO.stream(:stdio, :line),
        stderr_to_stdout: true,
        cd: File.cwd!()
      )

      System.halt(exit_code)
    end
  end
end
