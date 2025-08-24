defmodule Zonely.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ZonelyWeb.Telemetry,
      Zonely.Repo,
      {DNSCluster, query: Application.get_env(:zonely, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Zonely.PubSub},
      ZonelyWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Zonely.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    ZonelyWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
