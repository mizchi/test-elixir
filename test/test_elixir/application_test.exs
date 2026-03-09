defmodule TestElixir.ApplicationTest do
  use ExUnit.Case, async: true

  test "config_change delegates to the endpoint" do
    assert :ok = TestElixir.Application.config_change([], [], [])
  end
end
