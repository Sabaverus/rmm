defmodule Passme.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      # Start the Ecto repository
      Passme.Repo,
      # Start the endpoint when the application starts
      PassmeWeb.Endpoint,
      # Starts a worker by calling: Passme.Worker.start_link(arg)
      # {Passme.Worker, arg},
      Passme.User.Registry,
      Passme.User.Supervisor,
      ExGram,
      {Passme.Bot, [method: :polling, token: "796318981:AAGkUX7zUDvfNXRY1rOQfNd45OODwNPgiuE"]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Passme.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    PassmeWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
