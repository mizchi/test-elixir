defmodule TestElixirWeb.ConnectFourLobbyLive do
  use TestElixirWeb, :live_view

  alias TestElixir.ConnectFour.Server

  @impl true
  def mount(params, _session, socket) do
    player_id = Map.get(params, "player_id", generate_player_id())

    {:ok,
     assign(socket,
       page_title: "Connect Four Lobby",
       player_id: player_id,
       join_room_id: "",
       join_error: nil
     )}
  end

  @impl true
  def handle_event("create_room", _params, socket) do
    {:ok, room_id} = Server.create_room()

    {:noreply,
     push_navigate(socket, to: ~p"/connect-four/#{room_id}?player_id=#{socket.assigns.player_id}")}
  end

  def handle_event("update_join_room", %{"room_id" => room_id}, socket) do
    {:noreply, assign(socket, join_room_id: room_id, join_error: nil)}
  end

  def handle_event("join_room", _params, socket) do
    room_id = String.trim(socket.assigns.join_room_id)

    if room_id == "" do
      {:noreply, assign(socket, join_error: "Room ID is required")}
    else
      {:noreply,
       push_navigate(socket,
         to: ~p"/connect-four/#{room_id}?player_id=#{socket.assigns.player_id}"
       )}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="lobby-shell">
      <section class="hero-card">
        <p class="eyebrow">Realtime Game Server</p>
        <h1>Connect Four</h1>
        <p class="lede">
          One room is one OTP process. Open the same room URL in two browser windows and play.
        </p>
        <div class="identity-pill">
          <span>Player ID</span>
          <strong>{@player_id}</strong>
        </div>
      </section>

      <section class="action-grid">
        <article class="action-card">
          <h2>Create Room</h2>
          <p>Spin up a fresh room and claim the red seat.</p>
          <button class="cta-button" phx-click="create_room">Create Room</button>
        </article>

        <article class="action-card">
          <h2>Join Room</h2>
          <p>Reconnect or enter a room created elsewhere.</p>
          <form phx-submit="join_room" phx-change="update_join_room">
            <label for="room_id">Room ID</label>
            <input id="room_id" name="room_id" value={@join_room_id} autocomplete="off" />
            <button class="secondary-button" type="submit">Join Room</button>
          </form>
          <p :if={@join_error} class="error-copy">{@join_error}</p>
        </article>
      </section>
    </main>
    """
  end

  defp generate_player_id do
    "player-" <> Base.url_encode64(:crypto.strong_rand_bytes(6), padding: false)
  end
end
