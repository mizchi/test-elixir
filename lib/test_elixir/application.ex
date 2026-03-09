defmodule TestElixir.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TestElixirWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:test_elixir, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: TestElixir.PubSub},
      {TestElixir.Reminders.Server, name: TestElixir.Reminders.Server},
      TestElixirWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: TestElixir.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    TestElixirWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
