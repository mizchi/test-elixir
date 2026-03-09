import Config

config :test_elixir,
  generators: [timestamp_type: :utc_datetime]

config :test_elixir, TestElixirWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: TestElixirWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: TestElixir.PubSub

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
