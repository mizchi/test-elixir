defmodule TestElixirWeb.ConnCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  alias TestElixir.Reminders.Server

  using do
    quote do
      @endpoint TestElixirWeb.Endpoint

      use TestElixirWeb, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
      import TestElixirWeb.ConnCase
    end
  end

  setup _tags do
    :ok = Server.reset(TestElixir.Reminders.Server)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
