defmodule TestElixirWeb.Router do
  use TestElixirWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", TestElixirWeb do
    get "/", RootController, :index
  end

  scope "/api", TestElixirWeb do
    pipe_through :api

    get "/reminders", ReminderController, :index
    post "/reminders", ReminderController, :create
    patch "/reminders/:id/complete", ReminderController, :complete
  end
end
