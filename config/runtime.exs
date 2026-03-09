import Config

if System.get_env("PHX_SERVER") do
  config :test_elixir, TestElixirWeb.Endpoint, server: true
end

config :test_elixir, TestElixirWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      Generate one with: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "localhost"

  config :test_elixir, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :test_elixir, TestElixirWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base
end
