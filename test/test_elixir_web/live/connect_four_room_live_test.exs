defmodule TestElixirWeb.ConnectFourRoomLiveTest do
  use TestElixirWeb.ConnCase, async: false

  alias TestElixir.ConnectFour.Server

  test "renders room state and allows the active player to drop a token", %{conn: conn} do
    {:ok, room_id} = Server.create_room()

    {:ok, alice_view, html} = live(conn, "/connect-four/#{room_id}?player_id=alice")

    assert html =~ "Waiting for another player"

    {:ok, bob_view, _html} = live(build_conn(), "/connect-four/#{room_id}?player_id=bob")

    assert render(alice_view) =~ "Red to move"
    assert render(bob_view) =~ "Red to move"

    alice_view
    |> element("button[phx-value-column='0']")
    |> render_click()

    assert render(alice_view) =~ "Yellow to move"
    assert render(bob_view) =~ "Yellow to move"
    assert render(alice_view) =~ "disc-red"
  end

  test "reconnecting with the same player id resumes a paused room", %{conn: conn} do
    {:ok, room_id} = Server.create_room()

    {:ok, alice_view, _html} = live(conn, "/connect-four/#{room_id}?player_id=alice")
    {:ok, bob_view, _html} = live(build_conn(), "/connect-four/#{room_id}?player_id=bob")

    GenServer.stop(bob_view.pid)

    assert render(alice_view) =~ "Waiting for bob to reconnect"

    {:ok, _bob_view, html} = live(build_conn(), "/connect-four/#{room_id}?player_id=bob")

    assert html =~ "Yellow player"
    assert render(alice_view) =~ "Red to move"
  end

  test "missing rooms render a not found error", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/connect-four/missing-room?player_id=alice")

    assert html =~ "Room not found"
  end

  test "a third player sees a room full error", %{conn: conn} do
    {:ok, room_id} = Server.create_room()

    {:ok, _alice_view, _html} = live(conn, "/connect-four/#{room_id}?player_id=alice")
    {:ok, _bob_view, _html} = live(build_conn(), "/connect-four/#{room_id}?player_id=bob")
    {:ok, _carol_view, html} = live(build_conn(), "/connect-four/#{room_id}?player_id=carol")

    assert html =~ "Room is full"
  end

  test "invalid moves surface room errors in the UI", %{conn: conn} do
    {:ok, room_id} = Server.create_room()

    {:ok, alice_view, _html} = live(conn, "/connect-four/#{room_id}?player_id=alice")

    assert render_click(alice_view, :drop_token, %{"column" => 0}) =~ "Waiting for another player"

    {:ok, bob_view, _html} = live(build_conn(), "/connect-four/#{room_id}?player_id=bob")

    assert render_click(bob_view, :drop_token, %{"column" => 0}) =~ "It is not your turn"
    assert render_click(alice_view, :drop_token, %{"column" => "oops"}) =~ "Choose a valid column"
  end
end
