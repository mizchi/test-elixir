defmodule TestElixir.DefaultServerTest do
  use ExUnit.Case, async: false

  alias TestElixir.Reminders.Reminder
  alias TestElixir.Reminders.Server

  setup do
    :ok = Server.reset(TestElixir.Reminders.Server)
    :ok
  end

  test "uses the supervised default server when no server option is provided" do
    assert TestElixir.list_reminders() == []

    assert {:ok, reminder} = TestElixir.add_reminder("Plan trip", ~D[2026-04-01])

    assert reminder == %Reminder{
             id: 1,
             title: "Plan trip",
             due_on: ~D[2026-04-01],
             status: :pending
           }

    assert [^reminder] = TestElixir.list_reminders()
    assert TestElixir.overdue_reminders(~D[2026-03-10]) == []

    assert {:ok, completed} = TestElixir.complete_reminder(reminder.id)
    assert completed.status == :done
  end
end
