defmodule TestElixirWeb.ConnectFourRoomControllerTest do
  use TestElixirWeb.ConnCase, async: true

  test "POST /api/connect-four/rooms creates a room", %{conn: conn} do
    conn = post(conn, ~p"/api/connect-four/rooms")

    assert %{
             "data" => %{
               "room_id" => room_id,
               "topic" => topic,
               "websocket_path" => "/socket/websocket"
             }
           } = json_response(conn, 201)

    assert is_binary(room_id)
    assert String.starts_with?(topic, "connect_four:")
    assert topic == "connect_four:" <> room_id
  end
end
