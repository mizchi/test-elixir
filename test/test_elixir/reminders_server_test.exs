defmodule TestElixir.Reminders.ServerTest do
  use ExUnit.Case, async: true

  alias TestElixir.Reminders.Server

  test "rejects unsupported start options" do
    assert_raise ArgumentError, ~r/unsupported options/, fn ->
      Server.start_link(unexpected: true)
    end
  end

  test "keeps state unchanged when validation fails" do
    server = start_supervised!({Server, []})

    assert {:error, :blank_title} = Server.add(server, "   ", ~D[2026-03-10])
    assert {:error, :not_found} = Server.complete(server, 999)
    assert Server.list(server) == []
  end
end
