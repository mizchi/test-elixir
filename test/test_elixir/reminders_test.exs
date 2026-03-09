defmodule TestElixir.RemindersTest do
  use ExUnit.Case, async: true

  alias TestElixir.Reminders
  alias TestElixir.Reminders.Reminder

  describe "add/2" do
    test "creates a pending reminder with a sequential id" do
      reminders = Reminders.new()

      assert {:ok, updated, reminder} =
               Reminders.add(reminders, %{title: "Pay rent", due_on: ~D[2026-03-12]})

      assert reminder == %Reminder{
               id: 1,
               title: "Pay rent",
               due_on: ~D[2026-03-12],
               status: :pending
             }

      assert Reminders.list(updated) == [reminder]
    end

    test "rejects blank titles" do
      assert {:error, :blank_title} =
               Reminders.add(Reminders.new(), %{title: "   ", due_on: ~D[2026-03-12]})
    end

    test "requires a Date due_on value" do
      assert {:error, :invalid_due_on} =
               Reminders.add(Reminders.new(), %{title: "Pay rent"})
    end
  end

  describe "complete/2" do
    test "marks an existing reminder as done" do
      reminders = seed_reminders()

      assert {:ok, updated, completed} = Reminders.complete(reminders, 2)
      assert completed.status == :done

      assert Enum.map(Reminders.list(updated), &{&1.id, &1.status}) == [
               {1, :pending},
               {2, :done}
             ]
    end

    test "returns an error for unknown ids" do
      assert {:error, :not_found} = Reminders.complete(Reminders.new(), 99)
    end
  end

  describe "overdue/2" do
    test "lists only pending reminders due before the given date" do
      {:ok, reminders, overdue} =
        Reminders.add(Reminders.new(), %{title: "Pay rent", due_on: ~D[2026-03-01]})

      {:ok, reminders, completed} =
        Reminders.add(reminders, %{title: "Submit receipts", due_on: ~D[2026-03-02]})

      {:ok, reminders, _upcoming} =
        Reminders.add(reminders, %{title: "Book flight", due_on: ~D[2026-03-20]})

      assert {:ok, reminders, _done} = Reminders.complete(reminders, completed.id)

      assert Reminders.overdue(reminders, ~D[2026-03-10]) == [overdue]
    end
  end

  defp seed_reminders do
    {:ok, reminders, _} =
      Reminders.add(Reminders.new(), %{title: "Pay rent", due_on: ~D[2026-03-10]})

    {:ok, reminders, _} =
      Reminders.add(reminders, %{title: "Book flight", due_on: ~D[2026-03-12]})

    reminders
  end
end
