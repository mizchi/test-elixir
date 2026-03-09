defmodule TestElixir.ConnectFourTest do
  use ExUnit.Case, async: true

  alias TestElixir.ConnectFour

  test "players can join and the game becomes ready with two players" do
    game = ConnectFour.new("room-1")

    assert {:ok, waiting, :red} = ConnectFour.join(game, "alice")
    assert waiting.status == :waiting_for_player
    assert waiting.players == %{"alice" => :red}

    assert {:ok, ready, :yellow} = ConnectFour.join(waiting, "bob")
    assert ready.status == :ready
    assert ready.turn == :red
    assert ready.players == %{"alice" => :red, "bob" => :yellow}
  end

  test "drop_disc/3 enforces turn order and updates the board" do
    game =
      ConnectFour.new("room-2")
      |> join!("alice")
      |> join!("bob")

    assert {:error, :not_your_turn} = ConnectFour.drop_disc(game, "bob", 0)

    assert {:ok, updated} = ConnectFour.drop_disc(game, "alice", 0)
    assert updated.turn == :yellow
    assert updated.status == :ready
    assert ConnectFour.board_rows(updated) |> List.last() |> hd() == :red
  end

  test "drop_disc/3 detects a vertical winner" do
    game =
      ConnectFour.new("room-3")
      |> join!("alice")
      |> join!("bob")
      |> drop_sequence!(["alice", "bob", "alice", "bob", "alice", "bob"], [0, 1, 0, 1, 0, 1])

    assert {:ok, finished} = ConnectFour.drop_disc(game, "alice", 0)
    assert finished.status == :won
    assert finished.winner == :red
  end

  test "join/2 assigns a third unique player as spectator" do
    game =
      ConnectFour.new("room-4")
      |> join!("alice")
      |> join!("bob")

    assert {:ok, spectating, :spectator} = ConnectFour.join(game, "carol")
    assert spectating.status == :ready
    assert "carol" in spectating.spectators
    assert spectating.connections["carol"] == :connected
  end

  test "disconnecting pauses the room and reconnecting resumes it" do
    game =
      ConnectFour.new("room-5")
      |> join!("alice")
      |> join!("bob")

    assert {:ok, paused} = ConnectFour.disconnect(game, "bob")
    assert paused.status == :paused
    assert {:error, :waiting_for_reconnect} = ConnectFour.drop_disc(paused, "alice", 0)

    assert {:ok, resumed, :yellow} = ConnectFour.join(paused, "bob")
    assert resumed.status == :ready
    assert resumed.turn == :red
  end

  test "disconnecting and reconnecting a spectator does not pause the room" do
    game =
      ConnectFour.new("room-5b")
      |> join!("alice")
      |> join!("bob")
      |> spectate!("carol")

    assert {:ok, disconnected} = ConnectFour.disconnect(game, "carol")
    assert disconnected.status == :ready
    assert disconnected.connections["carol"] == :disconnected

    assert {:ok, reconnected, :spectator} = ConnectFour.join(disconnected, "carol")
    assert reconnected.status == :ready
    assert reconnected.connections["carol"] == :connected
  end

  test "drop_disc/3 rejects unknown players, invalid columns, and full columns" do
    game =
      ConnectFour.new("room-6")
      |> join!("alice")
      |> join!("bob")
      |> spectate!("carol")

    assert {:error, :spectator_cannot_play} = ConnectFour.drop_disc(game, "carol", 0)
    assert {:error, :unknown_player} = ConnectFour.drop_disc(game, "dan", 0)
    assert {:error, :invalid_column} = ConnectFour.drop_disc(game, "alice", -1)
    assert {:error, :invalid_column} = ConnectFour.drop_disc(game, "alice", 7)

    filled =
      drop_sequence!(
        game,
        ["alice", "bob", "alice", "bob", "alice", "bob"],
        [0, 0, 0, 0, 0, 0]
      )

    assert {:error, :column_full} = ConnectFour.drop_disc(filled, "alice", 0)
  end

  test "disconnect/2 rejects unknown players and game_over blocks moves" do
    game =
      ConnectFour.new("room-7")
      |> join!("alice")
      |> join!("bob")

    assert {:error, :unknown_player} = ConnectFour.disconnect(game, "carol")

    finished = %{game | status: :won, winner: :red}

    assert {:error, :game_over} = ConnectFour.drop_disc(finished, "alice", 0)
  end

  defp join!(game, player_id) do
    {:ok, joined, _color} = ConnectFour.join(game, player_id)
    joined
  end

  defp spectate!(game, player_id) do
    {:ok, spectating, :spectator} = ConnectFour.join(game, player_id)
    spectating
  end

  defp drop_sequence!(game, players, columns) do
    Enum.zip(players, columns)
    |> Enum.reduce(game, fn {player_id, column}, acc ->
      {:ok, updated} = ConnectFour.drop_disc(acc, player_id, column)
      updated
    end)
  end
end
