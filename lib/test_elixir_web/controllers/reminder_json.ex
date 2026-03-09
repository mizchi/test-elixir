defmodule TestElixirWeb.ReminderJSON do
  alias TestElixir.Reminders.Reminder

  def index(%{reminders: reminders}) do
    %{data: Enum.map(reminders, &data/1)}
  end

  def show(%{reminder: reminder}) do
    %{data: data(reminder)}
  end

  defp data(%Reminder{} = reminder) do
    %{
      id: reminder.id,
      title: reminder.title,
      due_on: Date.to_iso8601(reminder.due_on),
      status: Atom.to_string(reminder.status)
    }
  end
end
