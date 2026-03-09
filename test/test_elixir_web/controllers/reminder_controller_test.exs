defmodule TestElixirWeb.ReminderControllerTest do
  use TestElixirWeb.ConnCase, async: false

  test "GET /api/reminders returns the current reminders", %{conn: conn} do
    {:ok, reminder} = TestElixir.add_reminder("Pay rent", ~D[2026-03-15])

    conn = get(conn, ~p"/api/reminders")

    assert %{
             "data" => [
               %{
                 "id" => 1,
                 "title" => "Pay rent",
                 "due_on" => "2026-03-15",
                 "status" => "pending"
               }
             ]
           } = json_response(conn, 200)

    assert reminder.id == 1
  end

  test "POST /api/reminders creates a reminder", %{conn: conn} do
    conn =
      post(conn, ~p"/api/reminders", %{
        "title" => "Renew passport",
        "due_on" => "2026-03-18"
      })

    assert %{
             "data" => %{
               "id" => 1,
               "title" => "Renew passport",
               "due_on" => "2026-03-18",
               "status" => "pending"
             }
           } = json_response(conn, 201)
  end

  test "POST /api/reminders returns validation errors", %{conn: conn} do
    conn =
      post(conn, ~p"/api/reminders", %{
        "title" => "   ",
        "due_on" => "2026-03-18"
      })

    assert %{"errors" => %{"detail" => "blank_title"}} = json_response(conn, 422)
  end

  test "POST /api/reminders rejects invalid dates", %{conn: conn} do
    conn =
      post(conn, ~p"/api/reminders", %{
        "title" => "Renew passport",
        "due_on" => "not-a-date"
      })

    assert %{"errors" => %{"detail" => "invalid_due_on"}} = json_response(conn, 422)
  end

  test "PATCH /api/reminders/:id/complete marks a reminder done", %{conn: conn} do
    {:ok, reminder} = TestElixir.add_reminder("File taxes", ~D[2026-03-20])

    conn = patch(conn, ~p"/api/reminders/#{reminder.id}/complete")

    assert %{
             "data" => %{
               "id" => 1,
               "title" => "File taxes",
               "due_on" => "2026-03-20",
               "status" => "done"
             }
           } = json_response(conn, 200)
  end

  test "PATCH /api/reminders/:id/complete returns not found for unknown ids", %{conn: conn} do
    conn = patch(conn, ~p"/api/reminders/999/complete")

    assert %{"errors" => %{"detail" => "not_found"}} = json_response(conn, 404)
  end

  test "PATCH /api/reminders/:id/complete rejects invalid ids", %{conn: conn} do
    conn = patch(conn, ~p"/api/reminders/not-an-id/complete")

    assert %{"errors" => %{"detail" => "invalid_id"}} = json_response(conn, 400)
  end
end
