defmodule TestElixirWeb.Router do
  use TestElixirWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TestElixirWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", TestElixirWeb do
    get "/", RootController, :index
    get "/healthz", RootController, :health
  end

  scope "/", TestElixirWeb do
    pipe_through :browser

    live "/connect-four", ConnectFourLobbyLive
    live "/connect-four/:room_id", ConnectFourRoomLive
  end

  scope "/api", TestElixirWeb do
    pipe_through :api

    post "/connect-four/rooms", ConnectFourRoomController, :create
    get "/reminders", ReminderController, :index
    post "/reminders", ReminderController, :create
    patch "/reminders/:id/complete", ReminderController, :complete
  end
end
