import Config

config :test_elixir, TestElixirWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "3UZQdV0iXPv0M4XfpA0XYJ2m52m/7VzoAwqQj6Kv6Us6dc5k3h9nOt92Dg2P3JX2",
  server: false

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime
config :phoenix, sort_verified_routes_query_params: true
