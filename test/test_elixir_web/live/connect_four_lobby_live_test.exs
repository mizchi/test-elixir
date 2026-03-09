defmodule TestElixirWeb.ConnectFourLobbyLiveTest do
  use TestElixirWeb.ConnCase, async: true

  test "renders the connect four lobby", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/connect-four")

    assert html =~ "Connect Four"
    assert html =~ "Create Room"
    assert html =~ "Join Room"
  end

  test "creating a room navigates to the room page", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/connect-four")

    view
    |> element("button[phx-click='create_room']")
    |> render_click()

    {path, _flash} = assert_redirect(view)

    assert path =~ ~r|^/connect-four/[^?]+\?player_id=|
  end

  test "joining without a room id shows a validation error", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/connect-four")

    view
    |> form("form", %{room_id: ""})
    |> render_submit()

    assert render(view) =~ "Room ID is required"
  end

  test "joining an entered room navigates to that room", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/connect-four")

    view
    |> form("form", %{room_id: "demo-room"})
    |> render_change()

    view
    |> form("form", %{room_id: "demo-room"})
    |> render_submit()

    {path, _flash} = assert_redirect(view)

    assert path =~ ~r|^/connect-four/demo-room\?player_id=|
  end
end
