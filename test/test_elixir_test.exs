defmodule TestElixirTest do
  use ExUnit.Case, async: true

  alias TestElixir.Reminders.Reminder
  alias TestElixir.Reminders.Server

  setup do
    server = start_supervised!({Server, []})
    %{server: server}
  end

  test "creates and completes reminders through the public API", %{server: server} do
    assert {:ok, reminder} =
             TestElixir.add_reminder("Renew passport", ~D[2026-03-18], server: server)

    assert reminder == %Reminder{
             id: 1,
             title: "Renew passport",
             due_on: ~D[2026-03-18],
             status: :pending
           }

    assert [^reminder] = TestElixir.list_reminders(server: server)

    assert {:ok, completed} = TestElixir.complete_reminder(reminder.id, server: server)
    assert completed.status == :done
  end

  test "returns only overdue reminders through the public API", %{server: server} do
    assert {:ok, _} = TestElixir.add_reminder("Pay rent", ~D[2026-03-01], server: server)
    assert {:ok, future} = TestElixir.add_reminder("File taxes", ~D[2026-03-20], server: server)
    assert {:ok, _} = TestElixir.complete_reminder(future.id, server: server)

    assert Enum.map(TestElixir.overdue_reminders(~D[2026-03-10], server: server), & &1.title) ==
             ["Pay rent"]
  end
end
