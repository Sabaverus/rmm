defmodule Passme.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    token = ExGram.Config.get(:ex_gram, :token)

    children = [
      # Start the Ecto repository
      Passme.Repo,
      # Start the endpoint when the application starts
      PassmeWeb.Endpoint,
      # Starts a worker by calling: Passme.Worker.start_link(arg)
      # {Passme.Worker, arg},
      Passme.Chat.Registry,
      Passme.Chat.Supervisor,
      ExGram,
      {Passme.Bot, [method: :polling, token: token]}
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
