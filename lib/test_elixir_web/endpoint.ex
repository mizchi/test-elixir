defmodule TestElixirWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :test_elixir

  @session_options [
    store: :cookie,
    key: "_test_elixir_key",
    signing_salt: "8iNvQ0TQ",
    same_site: "Lax"
  ]

  socket "/socket", TestElixirWeb.UserSocket,
    websocket: true,
    longpoll: false

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: false

  plug Plug.Static,
    at: "/assets",
    from: {:test_elixir, "priv/static/assets"},
    gzip: false

  plug Plug.Static,
    at: "/vendor/phoenix",
    from: {:phoenix, "priv/static"},
    gzip: false,
    only: ~w(phoenix.min.js)

  plug Plug.Static,
    at: "/vendor/phoenix_live_view",
    from: {:phoenix_live_view, "priv/static"},
    gzip: false,
    only: ~w(phoenix_live_view.min.js)

  if code_reloading? do
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.Session, @session_options
  plug Plug.Head
  plug TestElixirWeb.Router
end
