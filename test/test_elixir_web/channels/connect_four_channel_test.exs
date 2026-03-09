defmodule TestElixirWeb.ConnectFourChannelTest do
  use TestElixirWeb.ChannelCase, async: true

  alias TestElixir.ConnectFour.Server
  alias TestElixirWeb.ConnectFourChannel
  alias TestElixirWeb.UserSocket

  test "joining a room assigns colors and transitions to ready" do
    {:ok, room_id} = Server.create_room()

    assert {:ok, %{player_color: "red", state: waiting}, alice_socket} =
             UserSocket
             |> socket("alice", %{player_id: "alice"})
             |> subscribe_and_join(ConnectFourChannel, "connect_four:" <> room_id)

    assert waiting["status"] == "waiting_for_player"

    assert {:ok, %{player_color: "yellow", state: ready}, _bob_socket} =
             UserSocket
             |> socket("bob", %{player_id: "bob"})
             |> subscribe_and_join(ConnectFourChannel, "connect_four:" <> room_id)

    assert ready["status"] == "ready"
    assert ready["turn"] == "red"

    assert_broadcast "state_updated", %{"state" => %{"status" => "ready"}}

    leave(alice_socket)
  end

  test "joining a missing room returns not_found" do
    assert {:error, %{"detail" => "not_found"}} =
             UserSocket
             |> socket("alice", %{player_id: "alice"})
             |> subscribe_and_join(ConnectFourChannel, "connect_four:missing-room")
  end

  test "drop_token broadcasts updated state to the room" do
    {:ok, room_id} = Server.create_room()

    {:ok, _, alice_socket} =
      UserSocket
      |> socket("alice", %{player_id: "alice"})
      |> subscribe_and_join(ConnectFourChannel, "connect_four:" <> room_id)

    {:ok, _, _bob_socket} =
      UserSocket
      |> socket("bob", %{player_id: "bob"})
      |> subscribe_and_join(ConnectFourChannel, "connect_four:" <> room_id)

    ref = push(alice_socket, "drop_token", %{"column" => 0})
    assert_reply ref, :ok

    assert_broadcast "state_updated", %{
      "state" => %{
        "turn" => "yellow",
        "board" => board
      }
    }

    assert List.last(board) == ["red", nil, nil, nil, nil, nil, nil]
  end

  test "drop_token rejects invalid turns" do
    {:ok, room_id} = Server.create_room()

    {:ok, _, _alice_socket} =
      UserSocket
      |> socket("alice", %{player_id: "alice"})
      |> subscribe_and_join(ConnectFourChannel, "connect_four:" <> room_id)

    {:ok, _, bob_socket} =
      UserSocket
      |> socket("bob", %{player_id: "bob"})
      |> subscribe_and_join(ConnectFourChannel, "connect_four:" <> room_id)

    ref = push(bob_socket, "drop_token", %{"column" => 0})
    assert_reply ref, :error, %{"detail" => "not_your_turn"}
  end

  test "drop_token rejects invalid columns" do
    {:ok, room_id} = Server.create_room()

    {:ok, _, alice_socket} =
      UserSocket
      |> socket("alice", %{player_id: "alice"})
      |> subscribe_and_join(ConnectFourChannel, "connect_four:" <> room_id)

    {:ok, _, _bob_socket} =
      UserSocket
      |> socket("bob", %{player_id: "bob"})
      |> subscribe_and_join(ConnectFourChannel, "connect_four:" <> room_id)

    ref = push(alice_socket, "drop_token", %{"column" => "oops"})
    assert_reply ref, :error, %{"detail" => "invalid_column"}
  end

  test "a third client joins as a spectator and cannot play" do
    {:ok, room_id} = Server.create_room()

    {:ok, _, _alice_socket} =
      UserSocket
      |> socket("alice", %{player_id: "alice"})
      |> subscribe_and_join(ConnectFourChannel, "connect_four:" <> room_id)

    {:ok, _, _bob_socket} =
      UserSocket
      |> socket("bob", %{player_id: "bob"})
      |> subscribe_and_join(ConnectFourChannel, "connect_four:" <> room_id)

    assert {:ok, %{player_role: "spectator", player_color: nil, state: state}, carol_socket} =
             UserSocket
             |> socket("carol", %{player_id: "carol"})
             |> subscribe_and_join(ConnectFourChannel, "connect_four:" <> room_id)

    assert state["spectators"] == ["carol"]

    ref = push(carol_socket, "drop_token", %{"column" => 0})
    assert_reply ref, :error, %{"detail" => "spectator_cannot_play"}
  end

  test "disconnecting pauses the room and reconnecting with the same player id resumes it" do
    Process.flag(:trap_exit, true)

    {:ok, room_id} = Server.create_room()

    {:ok, _, alice_socket} =
      UserSocket
      |> socket("alice", %{player_id: "alice"})
      |> subscribe_and_join(ConnectFourChannel, "connect_four:" <> room_id)

    {:ok, _, bob_socket} =
      UserSocket
      |> socket("bob", %{player_id: "bob"})
      |> subscribe_and_join(ConnectFourChannel, "connect_four:" <> room_id)

    leave(bob_socket)

    assert_broadcast "state_updated", %{
      "state" => %{
        "status" => "paused",
        "connections" => %{"bob" => "disconnected"}
      }
    }

    ref = push(alice_socket, "drop_token", %{"column" => 0})
    assert_reply ref, :error, %{"detail" => "waiting_for_reconnect"}

    assert {:ok, %{player_color: "yellow", state: resumed}, _bob_socket} =
             UserSocket
             |> socket("bob", %{player_id: "bob"})
             |> subscribe_and_join(ConnectFourChannel, "connect_four:" <> room_id)

    assert resumed["status"] == "ready"
    assert resumed["connections"] == %{"alice" => "connected", "bob" => "connected"}
  end
end
