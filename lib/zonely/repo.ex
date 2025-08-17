defmodule Zonely.Repo do
  use Ecto.Repo,
    otp_app: :zonely,
    adapter: Ecto.Adapters.Postgres
end