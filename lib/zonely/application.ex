defmodule Zonely.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    attach_scout_telemetry()

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

  defp attach_scout_telemetry do
    :ok = ScoutApm.Instruments.EctoTelemetry.attach(Zonely.Repo)
    :ok = ScoutApm.Instruments.LiveViewTelemetry.attach()
    :ok = ScoutApm.Instruments.FinchTelemetry.attach()
    :ok = ScoutApm.Instruments.PhoenixErrorTelemetry.attach()
  end
end
