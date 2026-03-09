defmodule TestElixir.ConnectFour.ServerTest do
  use ExUnit.Case, async: true

  alias TestElixir.ConnectFour.Server

  test "create_room/0 starts a retrievable room" do
    assert {:ok, room_id} = Server.create_room()
    assert {:ok, game} = Server.state(room_id)

    assert game.id == room_id
    assert game.status == :waiting_for_player
  end

  test "returns not_found for unknown rooms" do
    assert {:error, :not_found} = Server.state("missing-room")
    assert {:error, :not_found} = Server.join_room("missing-room", "alice")
    assert {:error, :not_found} = Server.drop_disc("missing-room", "alice", 0)
    assert {:error, :not_found} = Server.disconnect_player("missing-room", "alice")
  end

  test "disconnect_player/2 returns unknown_player for non-members" do
    assert {:ok, room_id} = Server.create_room()
    assert {:ok, _game, :red} = Server.join_room(room_id, "alice")

    assert {:error, :unknown_player} = Server.disconnect_player(room_id, "bob")
  end
end
