defmodule TestElixirWeb.RootController do
  use TestElixirWeb, :controller

  def index(conn, _params) do
    if wants_json?(conn) do
      json(conn, %{
        name: "test_elixir",
        status: "ok",
        endpoints: %{
          list_reminders: "/api/reminders",
          create_reminder: "/api/reminders",
          complete_reminder: "/api/reminders/:id/complete"
        }
      })
    else
      text(conn, """
      TestElixir API
      GET /api/reminders
      POST /api/reminders
      PATCH /api/reminders/:id/complete
      """)
    end
  end

  defp wants_json?(conn) do
    Enum.any?(get_req_header(conn, "accept"), &String.contains?(&1, "application/json"))
  end
end
