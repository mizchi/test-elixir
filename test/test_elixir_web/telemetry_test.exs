defmodule TestElixirWeb.TelemetryTest do
  use ExUnit.Case, async: true

  test "defines endpoint and VM metrics" do
    metrics = TestElixirWeb.Telemetry.metrics()

    assert Enum.any?(metrics, fn metric ->
             Map.get(metric, :name) == [:phoenix, :endpoint, :stop, :duration]
           end)

    assert Enum.any?(metrics, fn metric ->
             Map.get(metric, :name) == [:vm, :memory, :total]
           end)
  end
end
