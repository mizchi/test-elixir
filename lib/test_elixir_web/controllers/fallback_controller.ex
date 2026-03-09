defmodule TestElixirWeb.FallbackController do
  use TestElixirWeb, :controller

  def call(conn, {:error, reason}) do
    {status, detail} = error_response(reason)

    conn
    |> put_status(status)
    |> json(%{errors: %{detail: detail}})
  end

  defp error_response(:blank_title), do: {:unprocessable_entity, "blank_title"}
  defp error_response(:invalid_due_on), do: {:unprocessable_entity, "invalid_due_on"}
  defp error_response(:invalid_id), do: {:bad_request, "invalid_id"}
  defp error_response(:not_found), do: {:not_found, "not_found"}
  defp error_response(reason), do: {:internal_server_error, to_string(reason)}
end
