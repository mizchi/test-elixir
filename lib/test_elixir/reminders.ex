defmodule TestElixir.Reminders do
  @moduledoc """
  Pure domain logic for reminder management.

  State is represented as a value, which makes the module easy to test
  and keeps OTP-specific concerns outside the domain layer.
  """

  alias TestElixir.Reminders.Reminder

  defstruct next_id: 1, order: [], entries: %{}

  @type id :: pos_integer()
  @type add_error :: :blank_title | :invalid_due_on

  @type t :: %__MODULE__{
          next_id: id(),
          order: [id()],
          entries: %{id() => Reminder.t()}
        }

  @type empty_t :: %__MODULE__{
          next_id: 1,
          order: [],
          entries: %{}
        }

  @spec new() :: empty_t()
  def new do
    %__MODULE__{}
  end

  @spec add(t(), %{required(:title) => String.t(), required(:due_on) => Date.t()}) ::
          {:ok, t(), Reminder.t()} | {:error, add_error()}
  def add(%__MODULE__{} = reminders, %{title: title, due_on: %Date{} = due_on})
      when is_binary(title) do
    case String.trim(title) do
      "" ->
        {:error, :blank_title}

      normalized_title ->
        reminder = %Reminder{
          id: reminders.next_id,
          title: normalized_title,
          due_on: due_on,
          status: :pending
        }

        updated = %__MODULE__{
          reminders
          | next_id: reminders.next_id + 1,
            order: reminders.order ++ [reminder.id],
            entries: Map.put(reminders.entries, reminder.id, reminder)
        }

        {:ok, updated, reminder}
    end
  end

  def add(%__MODULE__{}, %{title: title}) when is_binary(title) do
    {:error, :invalid_due_on}
  end

  def add(%__MODULE__{}, _attrs) do
    {:error, :blank_title}
  end

  @spec list(t()) :: [Reminder.t()]
  def list(%__MODULE__{order: order, entries: entries}) do
    Enum.map(order, &Map.fetch!(entries, &1))
  end

  @spec complete(t(), pos_integer()) :: {:ok, t(), Reminder.t()} | {:error, :not_found}
  def complete(%__MODULE__{} = reminders, id) when is_integer(id) and id > 0 do
    case Map.fetch(reminders.entries, id) do
      {:ok, reminder} ->
        completed = Reminder.complete(reminder)

        updated =
          %__MODULE__{
            reminders
            | entries: Map.put(reminders.entries, id, completed)
          }

        {:ok, updated, completed}

      :error ->
        {:error, :not_found}
    end
  end

  def complete(%__MODULE__{}, _id) do
    {:error, :not_found}
  end

  @spec overdue(t(), Date.t()) :: [Reminder.t()]
  def overdue(%__MODULE__{} = reminders, %Date{} = on_date) do
    reminders
    |> list()
    |> Enum.filter(fn reminder ->
      reminder.status == :pending and Date.compare(reminder.due_on, on_date) == :lt
    end)
  end
end
