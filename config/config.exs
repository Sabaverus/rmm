# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :passme,
  ecto_repos: [Passme.Repo]

# Configures the endpoint
config :passme, PassmeWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "G6A9WEl/00c2uflNCYQYxA2Xi4a2gOarKk6VRT90a9FzOPMEol/iD4xr+HCFKbJe",
  render_errors: [view: PassmeWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Passme.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :ex_gram, token: "796318981:AAGkUX7zUDvfNXRY1rOQfNd45OODwNPgiuE"

# config :tesla, adapter: Tesla.Adapter.Gun

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
