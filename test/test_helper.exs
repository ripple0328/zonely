ExUnit.start()

# Ensure test support modules are loaded when running single files
Code.require_file("support/data_case.ex", __DIR__)
Code.require_file("support/component_case.ex", __DIR__)
Code.require_file("support/feature_case.ex", __DIR__)
Code.require_file("support/fake_http_client.ex", __DIR__)

# Ensure core libraries used by component rendering are started when using --no-start
{:ok, _} = Application.ensure_all_started(:phoenix)
{:ok, _} = Application.ensure_all_started(:phoenix_html)
{:ok, _} = Application.ensure_all_started(:phoenix_live_view)

# Start Wallaby if running browser tests
if System.get_env("WALLABY_ENABLE_SERVER") == "true" do
  try do
    {:ok, _} = Application.ensure_all_started(:wallaby)
  rescue
    _ -> :ok  # Ignore wallaby startup errors - they'll be handled later
  end
end
