defmodule TestElixirWeb.ReminderController do
  use TestElixirWeb, :controller

  action_fallback TestElixirWeb.FallbackController

  alias TestElixirWeb.ReminderParams

  def index(conn, _params) do
    render(conn, :index, reminders: TestElixir.list_reminders())
  end

  def create(conn, params) do
    with {:ok, attrs} <- ReminderParams.parse_create(params),
         {:ok, reminder} <- TestElixir.add_reminder(attrs.title, attrs.due_on) do
      conn
      |> put_status(:created)
      |> render(:show, reminder: reminder)
    end
  end

  def complete(conn, %{"id" => raw_id}) do
    with {:ok, id} <- parse_id(raw_id),
         {:ok, reminder} <- TestElixir.complete_reminder(id) do
      render(conn, :show, reminder: reminder)
    end
  end

  defp parse_id(raw_id) when is_binary(raw_id) do
    case Integer.parse(raw_id) do
      {id, ""} when id > 0 -> {:ok, id}
      _ -> {:error, :invalid_id}
    end
  end

  defp parse_id(_raw_id), do: {:error, :invalid_id}
end
