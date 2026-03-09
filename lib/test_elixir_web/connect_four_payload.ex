defmodule TestElixirWeb.ConnectFourPayload do
  @moduledoc false

  alias TestElixir.ConnectFour

  def room(room_id) do
    %{
      room_id: room_id,
      topic: "connect_four:" <> room_id,
      websocket_path: "/socket/websocket"
    }
  end

  def state(%ConnectFour{} = game) do
    %{
      "room_id" => game.id,
      "status" => Atom.to_string(game.status),
      "turn" => turn(game),
      "winner" => encode_color(game.winner),
      "players" => encode_players(game.players),
      "connections" => encode_connections(game.connections),
      "board" => encode_board(ConnectFour.board_rows(game))
    }
  end

  defp turn(%ConnectFour{status: :ready, turn: turn}), do: encode_color(turn)
  defp turn(%ConnectFour{}), do: nil

  defp encode_players(players) do
    Map.new(players, fn {player_id, color} ->
      {player_id, encode_color(color)}
    end)
  end

  defp encode_connections(connections) do
    Map.new(connections, fn {player_id, status} ->
      {player_id, Atom.to_string(status)}
    end)
  end

  defp encode_board(rows) do
    Enum.map(rows, fn row ->
      Enum.map(row, &encode_color/1)
    end)
  end

  defp encode_color(nil), do: nil
  defp encode_color(color), do: Atom.to_string(color)
end
