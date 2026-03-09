import Config

config :test_elixir, TestElixirWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "UaVICN8n6Ha2M8bG1kofubQeJmJoR1Kbl5NaMGRyr0ifI0bG4i4SxSi/3jLwKQ1j",
  watchers: []

config :logger, :default_formatter, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
