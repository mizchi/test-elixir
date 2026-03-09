defmodule TestElixir.Reminders.Reminder do
  @moduledoc """
  Immutable reminder entity.
  """

  @enforce_keys [:id, :title, :due_on, :status]
  defstruct [:id, :title, :due_on, :status]

  @type status :: :pending | :done

  @type t :: %__MODULE__{
          id: pos_integer(),
          title: String.t(),
          due_on: Date.t(),
          status: status()
        }

  @spec complete(t()) :: t()
  def complete(%__MODULE__{} = reminder) do
    %__MODULE__{reminder | status: :done}
  end
end
