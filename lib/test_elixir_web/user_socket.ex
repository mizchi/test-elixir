defmodule TestElixirWeb.UserSocket do
  use Phoenix.Socket

  channel "connect_four:*", TestElixirWeb.ConnectFourChannel

  @impl true
  def connect(%{"player_id" => player_id}, socket, _connect_info)
      when is_binary(player_id) and byte_size(player_id) > 0 do
    {:ok, assign(socket, :player_id, player_id)}
  end

  def connect(_params, socket, _connect_info) do
    {:ok, assign(socket, :player_id, generate_player_id())}
  end

  @impl true
  def id(socket) do
    "players_socket:" <> socket.assigns.player_id
  end

  defp generate_player_id do
    "player-" <> Base.url_encode64(:crypto.strong_rand_bytes(6), padding: false)
  end
end
