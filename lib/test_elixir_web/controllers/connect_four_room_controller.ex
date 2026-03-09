defmodule TestElixirWeb.ConnectFourRoomController do
  use TestElixirWeb, :controller

  alias TestElixir.ConnectFour.Server
  alias TestElixirWeb.ConnectFourPayload

  def create(conn, _params) do
    {:ok, room_id} = Server.create_room()

    conn
    |> put_status(:created)
    |> json(%{data: ConnectFourPayload.room(room_id)})
  end
end
