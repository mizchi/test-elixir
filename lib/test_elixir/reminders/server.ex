defmodule TestElixir.Reminders.Server do
  @moduledoc """
  In-memory OTP process that owns reminder state.
  """

  use GenServer

  alias TestElixir.Reminders
  alias TestElixir.Reminders.Reminder

  @type option :: {:name, GenServer.name()}
  @type server :: GenServer.server()

  @spec start_link([option()]) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name)
    start_opts = if name, do: [name: name], else: []

    if opts != [] do
      raise ArgumentError, "unsupported options: #{inspect(opts)}"
    end

    GenServer.start_link(__MODULE__, Reminders.new(), start_opts)
  end

  @spec add(server(), String.t(), Date.t()) ::
          {:ok, Reminder.t()} | {:error, Reminders.add_error()}
  def add(server, title, due_on) do
    GenServer.call(server, {:add, title, due_on})
  end

  @spec list(server()) :: [Reminder.t()]
  def list(server) do
    GenServer.call(server, :list)
  end

  @spec complete(server(), pos_integer()) :: {:ok, Reminder.t()} | {:error, :not_found}
  def complete(server, id) do
    GenServer.call(server, {:complete, id})
  end

  @spec overdue(server(), Date.t()) :: [Reminder.t()]
  def overdue(server, on_date) do
    GenServer.call(server, {:overdue, on_date})
  end

  @spec reset(server()) :: :ok
  def reset(server) do
    GenServer.call(server, :reset)
  end

  @impl true
  def init(reminders) do
    {:ok, reminders}
  end

  @impl true
  def handle_call({:add, title, due_on}, _from, reminders) do
    case Reminders.add(reminders, %{title: title, due_on: due_on}) do
      {:ok, updated, reminder} ->
        {:reply, {:ok, reminder}, updated}

      {:error, reason} ->
        {:reply, {:error, reason}, reminders}
    end
  end

  def handle_call(:list, _from, reminders) do
    {:reply, Reminders.list(reminders), reminders}
  end

  def handle_call({:complete, id}, _from, reminders) do
    case Reminders.complete(reminders, id) do
      {:ok, updated, reminder} ->
        {:reply, {:ok, reminder}, updated}

      {:error, reason} ->
        {:reply, {:error, reason}, reminders}
    end
  end

  def handle_call({:overdue, on_date}, _from, reminders) do
    {:reply, Reminders.overdue(reminders, on_date), reminders}
  end

  def handle_call(:reset, _from, _reminders) do
    {:reply, :ok, Reminders.new()}
  end
end
