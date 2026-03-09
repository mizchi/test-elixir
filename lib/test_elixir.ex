defmodule TestElixir do
  @moduledoc """
  Public API for the reminder application.

  The default runtime uses the supervised `TestElixir.Reminders.Server`,
  while tests can inject a dedicated process with the `:server` option.
  """

  alias TestElixir.Reminders.Reminder
  alias TestElixir.Reminders.Server

  @type option :: {:server, GenServer.server()}

  @default_server Server

  @spec add_reminder(String.t(), Date.t(), [option()]) ::
          {:ok, Reminder.t()} | {:error, TestElixir.Reminders.add_error()}
  def add_reminder(title, due_on, opts \\ []) do
    Server.add(server(opts), title, due_on)
  end

  @spec list_reminders([option()]) :: [Reminder.t()]
  def list_reminders(opts \\ []) do
    Server.list(server(opts))
  end

  @spec complete_reminder(pos_integer(), [option()]) ::
          {:ok, Reminder.t()} | {:error, :not_found}
  def complete_reminder(id, opts \\ []) do
    Server.complete(server(opts), id)
  end

  @spec overdue_reminders(Date.t(), [option()]) :: [Reminder.t()]
  def overdue_reminders(on_date, opts \\ []) do
    Server.overdue(server(opts), on_date)
  end

  defp server(opts) do
    Keyword.get(opts, :server, @default_server)
  end
end
