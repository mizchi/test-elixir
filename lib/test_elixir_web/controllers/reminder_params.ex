defmodule TestElixirWeb.ReminderParams do
  @moduledoc false

  @type create_attrs :: %{title: String.t(), due_on: Date.t()}

  @spec parse_create(map()) :: {:ok, create_attrs()} | {:error, :blank_title | :invalid_due_on}
  def parse_create(%{"title" => title, "due_on" => due_on})
      when is_binary(title) and is_binary(due_on) do
    case Date.from_iso8601(due_on) do
      {:ok, date} -> {:ok, %{title: title, due_on: date}}
      {:error, _reason} -> {:error, :invalid_due_on}
    end
  end

  def parse_create(%{"title" => title}) when is_binary(title) do
    {:error, :invalid_due_on}
  end

  def parse_create(_params) do
    {:error, :blank_title}
  end
end
