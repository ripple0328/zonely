ExUnit.start()

# Ensure core libraries used by component rendering are started when using --no-start
{:ok, _} = Application.ensure_all_started(:phoenix)
{:ok, _} = Application.ensure_all_started(:phoenix_html)
{:ok, _} = Application.ensure_all_started(:phoenix_live_view)

