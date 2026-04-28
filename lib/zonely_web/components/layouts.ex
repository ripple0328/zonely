defmodule ZonelyWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered around the page that contains
  common elements, like the HTML head, navigation bar, footer, etc.
  The "app" layout is rendered inside the "root" layout and contains all
  the content for a specific page.
  """
  use ZonelyWeb, :html

  embed_templates("layouts/*")

  @doc """
  Runtime PostHog browser configuration for the bundled JavaScript initializer.
  """
  def posthog_browser_config(assigns) do
    config = Application.get_env(:zonely, :posthog_browser, [])
    api_key = config_value(config, :api_key, nil)

    enabled? =
      config_value(config, :enabled, false) == true and is_binary(api_key) and api_key != ""

    assigns =
      assign(assigns,
        enabled: enabled?,
        api_key: api_key,
        api_host: config_value(config, :api_host, "https://us.i.posthog.com"),
        app: config_value(config, :app, "zonely"),
        env: config_value(config, :env, "prod")
      )

    ~H"""
    <%= if @enabled do %>
      <meta name="posthog-api-key" content={@api_key} />
      <meta name="posthog-api-host" content={@api_host} />
      <meta name="posthog-app" content={@app} />
      <meta name="posthog-env" content={@env} />
    <% end %>
    """
  end

  defp config_value(config, key, default) when is_list(config),
    do: Keyword.get(config, key, default)

  defp config_value(config, key, default) when is_map(config) do
    Map.get(config, key) || Map.get(config, Atom.to_string(key), default)
  end

  defp config_value(_config, _key, default), do: default
end
