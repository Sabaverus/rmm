defmodule Passme.Repo do
  use Ecto.Repo,
    otp_app: :passme,
    adapter: Ecto.Adapters.Postgres
end
