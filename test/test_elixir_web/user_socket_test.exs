defmodule TestElixirWeb.UserSocketTest do
  use ExUnit.Case, async: true

  alias TestElixirWeb.UserSocket

  test "connect/3 preserves an explicit player id" do
    socket = %Phoenix.Socket{assigns: %{}}

    assert {:ok, connected} = UserSocket.connect(%{"player_id" => "alice"}, socket, %{})
    assert connected.assigns.player_id == "alice"
  end

  test "connect/3 generates a player id when one is missing" do
    socket = %Phoenix.Socket{assigns: %{}}

    assert {:ok, connected} = UserSocket.connect(%{}, socket, %{})
    assert String.starts_with?(connected.assigns.player_id, "player-")
  end

  test "id/1 uses the player id namespace" do
    socket = %Phoenix.Socket{assigns: %{player_id: "alice"}}

    assert UserSocket.id(socket) == "players_socket:alice"
  end
end
