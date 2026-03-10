defmodule TestElixirWeb.RootControllerTest do
  use TestElixirWeb.ConnCase, async: true

  test "GET / returns a plain text landing page", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert response(conn, 200) =~ "TestElixir API"
    assert response(conn, 200) =~ "GET /healthz"
    assert response(conn, 200) =~ "GET /api/reminders"
  end

  test "GET / returns JSON when the client requests it", %{conn: conn} do
    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> get(~p"/")

    assert json_response(conn, 200) == %{
             "name" => "test_elixir",
             "status" => "ok",
             "endpoints" => %{
               "health" => "/healthz",
               "list_reminders" => "/api/reminders",
               "create_reminder" => "/api/reminders",
               "complete_reminder" => "/api/reminders/:id/complete"
             }
           }
  end

  test "GET /healthz returns plain text health status", %{conn: conn} do
    conn = get(conn, ~p"/healthz")

    assert response(conn, 200) == "ok\n"
  end

  test "GET /healthz returns JSON when the client requests it", %{conn: conn} do
    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> get(~p"/healthz")

    assert json_response(conn, 200) == %{"status" => "ok"}
  end
end
