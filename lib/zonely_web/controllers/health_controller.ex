defmodule ZonelyWeb.HealthController do
  @moduledoc """
  Health check endpoints for monitoring (GAT-99).
  
  - /healthz: Liveness probe (is the app running?)
  - /readyz: Readiness probe (can it serve traffic?)
  - /version: Build/version info
  """
  
  use ZonelyWeb, :controller
  require Logger

  @doc """
  Liveness probe - returns 200 if application is alive.
  This should always return 200 unless the app is completely broken.
  """
  def liveness(conn, _params) do
    json(conn, %{
      status: "ok",
      service: "zonely",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  @doc """
  Readiness probe - returns 200 if app can serve traffic.
  Checks:
  - Database connectivity
  - Any critical external dependencies
  """
  def readiness(conn, _params) do
    checks = %{
      database: check_database(),
      # Add more checks here as needed
    }
    
    all_healthy = Enum.all?(checks, fn {_name, status} -> status == :ok end)
    status_code = if all_healthy, do: 200, else: 503
    
    response = %{
      status: if(all_healthy, do: "ready", else: "not_ready"),
      checks: checks,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
    
    conn
    |> put_status(status_code)
    |> json(response)
  end

  @doc """
  Version endpoint - returns build/deploy information.
  """
  def version(conn, _params) do
    json(conn, %{
      service: "zonely",
      version: Application.spec(:zonely, :vsn) |> to_string(),
      elixir_version: System.version(),
      otp_release: :erlang.system_info(:otp_release) |> to_string(),
      hostname: :inet.gethostname() |> elem(1) |> to_string(),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  # Private helpers

  defp check_database do
    try do
      # Simple query to verify DB connection
      case Zonely.Repo.query("SELECT 1") do
        {:ok, _result} -> :ok
        {:error, reason} -> 
          Logger.error("Database health check failed: #{inspect(reason)}")
          :error
      end
    rescue
      e ->
        Logger.error("Database health check exception: #{inspect(e)}")
        :error
    end
  end
end
