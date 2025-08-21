defmodule Mix.Tasks.Deploy do
  @moduledoc """
  Deploy the Zonely application to Fly.io

  ## Usage

      mix deploy

  This task will:
  1. Check if flyctl is installed
  2. Build assets for production
  3. Deploy to Fly.io using flyctl

  ## Initial Setup
  Before first deployment, run these commands to set up your app with an existing database:
  
      flyctl launch --no-deploy
      flyctl postgres attach YOUR-EXISTING-DB-APP
      mix deploy
  """

  use Mix.Task

  @shortdoc "Deploy the application to Fly.io"

  def run(_args) do
    Mix.shell().info("🚀 Starting deployment to Fly.io...")

    with :ok <- check_flyctl(),
         :ok <- build_assets(),
         :ok <- deploy_to_fly() do
      Mix.shell().info("✅ Deployment completed successfully!")
    else
      {:error, reason} ->
        Mix.shell().error("❌ Deployment failed: #{reason}")
        System.halt(1)
    end
  end

  defp check_flyctl do
    case System.cmd("flyctl", ["version"], stderr_to_stdout: true) do
      {_, 0} ->
        Mix.shell().info("✓ flyctl is installed")
        :ok

      _ ->
        {:error, "flyctl is not installed. Please install it from https://fly.io/docs/flyctl/installing/"}
    end
  end

  defp build_assets do
    Mix.shell().info("📦 Building production assets...")

    case Mix.Task.run("assets.deploy") do
      :ok ->
        Mix.shell().info("✓ Assets built successfully")
        :ok

      _ ->
        {:error, "Failed to build assets"}
    end
  end

  defp deploy_to_fly do
    Mix.shell().info("🛫 Deploying to Fly.io...")

    case System.cmd("flyctl", ["deploy"], into: IO.stream(:stdio, :line)) do
      {_, 0} ->
        Mix.shell().info("✓ Successfully deployed to Fly.io")
        :ok

      {_, exit_code} ->
        {:error, "flyctl deploy failed with exit code #{exit_code}"}
    end
  end
end