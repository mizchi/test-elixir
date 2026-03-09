defmodule TestElixirWeb.ConnectFourRoomLive do
  use TestElixirWeb, :live_view

  alias TestElixir.ConnectFour.Server
  alias TestElixirWeb.ConnectFourPayload
  alias TestElixirWeb.Endpoint

  @impl true
  def mount(%{"room_id" => room_id} = params, _session, socket) do
    player_id = Map.get(params, "player_id", "guest")
    topic = topic(room_id)

    socket =
      assign(socket,
        page_title: "Connect Four #{room_id}",
        room_id: room_id,
        topic: topic,
        player_id: player_id,
        player_role: nil,
        player_color: nil,
        state: initial_state(room_id),
        room_error: nil,
        joined?: false
      )

    socket =
      if connected?(socket) do
        subscribe_topic(topic)
        socket |> join_room() |> maybe_broadcast_join()
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("drop_token", %{"column" => raw_column}, socket) do
    with {column, ""} <- Integer.parse(to_string(raw_column)),
         {:ok, game} <- Server.drop_disc(socket.assigns.room_id, socket.assigns.player_id, column) do
      broadcast_state(game)

      {:noreply, assign(socket, state: ConnectFourPayload.state(game), room_error: nil)}
    else
      {:error, reason} ->
        {:noreply, assign(socket, room_error: human_error(reason))}

      _ ->
        {:noreply, assign(socket, room_error: human_error(:invalid_column))}
    end
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{event: "state_updated", payload: %{"state" => state}},
        socket
      ) do
    {:noreply, assign(socket, state: state, room_error: nil)}
  end

  @impl true
  def terminate(_reason, socket) do
    if socket.assigns[:joined?] do
      case Server.disconnect_player(socket.assigns.room_id, socket.assigns.player_id) do
        {:ok, game} -> broadcast_state(game)
        _ -> :ok
      end
    end

    :ok
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="room-shell">
      <section class="room-header">
        <div>
          <p class="eyebrow">Connect Four Room</p>
          <h1>{@room_id}</h1>
        </div>
        <div class="status-stack">
          <span class="identity-pill"><strong>{@player_id}</strong></span>
          <span :if={@player_role} class={["seat-badge", badge_class(@player_role)]}>
            {role_label(@player_role)}
          </span>
        </div>
      </section>

      <section :if={@room_error} class="room-error">{@room_error}</section>

      <section :if={!@room_error} class="board-panel">
        <header class="board-meta">
          <p class="turn-banner">{status_message(@state)}</p>
          <p class="subtle-copy">
            Share this URL to reconnect: <code>{~p"/connect-four/#{@room_id}?player_id=#{@player_id}"}</code>
          </p>
        </header>

        <div class="column-buttons">
          <button
            :for={column <- 0..6}
            class="column-button"
            phx-click="drop_token"
            phx-value-column={column}
            disabled={!can_play?(@state, @player_color)}
          >
            Drop {column + 1}
          </button>
        </div>

        <div class="board-grid">
          <div :for={row <- @state["board"] || blank_board()} class="board-row">
            <div
              :for={cell <- row}
              class={["board-cell", cell && "disc-#{cell}"]}
            >
            </div>
          </div>
        </div>

        <section class="presence-panel">
          <h2>Players</h2>
          <ul>
            <li :for={{player_id, color} <- @state["players"] || %{}}>
              <span class={["seat-badge", color]}>{String.capitalize(color)}</span>
              <strong>{player_id}</strong>
              <em>{Map.get(@state["connections"] || %{}, player_id, "unknown")}</em>
            </li>
          </ul>
        </section>

        <section class="presence-panel">
          <h2>Spectators</h2>
          <ul>
            <li :for={player_id <- @state["spectators"] || []}>
              <span class={["seat-badge", "spectator"]}>Spectator</span>
              <strong>{player_id}</strong>
              <em>{Map.get(@state["connections"] || %{}, player_id, "unknown")}</em>
            </li>
            <li :if={Enum.empty?(@state["spectators"] || [])}>
              <em>No spectators yet</em>
            </li>
          </ul>
        </section>
      </section>
    </main>
    """
  end

  defp join_room(socket) do
    case Server.join_room(socket.assigns.room_id, socket.assigns.player_id) do
      {:ok, game, :spectator} ->
        assign(socket,
          player_role: "spectator",
          player_color: nil,
          state: ConnectFourPayload.state(game),
          joined?: true,
          room_error: nil
        )

      {:ok, game, color} ->
        assign(socket,
          player_role: Atom.to_string(color),
          player_color: Atom.to_string(color),
          state: ConnectFourPayload.state(game),
          joined?: true,
          room_error: nil
        )

      {:error, :not_found} ->
        assign(socket, room_error: "Room not found")
    end
  end

  defp maybe_broadcast_join(%{assigns: %{joined?: true, room_error: nil, state: _state}} = socket) do
    {:ok, game} = Server.state(socket.assigns.room_id)
    broadcast_state(game)
    socket
  end

  defp maybe_broadcast_join(socket), do: socket

  defp initial_state(room_id) do
    case Server.state(room_id) do
      {:ok, game} -> ConnectFourPayload.state(game)
      {:error, :not_found} -> nil
    end
  end

  defp status_message(nil), do: "Room not found"
  defp status_message(%{"status" => "waiting_for_player"}), do: "Waiting for another player"

  defp status_message(%{"status" => "paused", "connections" => connections}) do
    disconnected_player =
      connections
      |> Enum.find_value(fn {player_id, status} ->
        if status == "disconnected", do: player_id
      end)

    "Waiting for #{disconnected_player} to reconnect"
  end

  defp status_message(%{"status" => "ready", "turn" => turn}) do
    "#{String.capitalize(turn)} to move"
  end

  defp status_message(%{"status" => "won", "winner" => winner}) do
    "#{String.capitalize(winner)} wins"
  end

  defp status_message(%{"status" => "draw"}), do: "Draw"

  defp can_play?(%{"status" => "ready", "turn" => turn}, player_color)
       when is_binary(player_color) do
    turn == player_color
  end

  defp can_play?(_state, _player_color), do: false

  defp human_error(:waiting_for_opponent), do: "Waiting for another player"
  defp human_error(:waiting_for_reconnect), do: "Waiting for a player to reconnect"
  defp human_error(:spectator_cannot_play), do: "Spectators cannot play"
  defp human_error(:not_your_turn), do: "It is not your turn"
  defp human_error(:invalid_column), do: "Choose a valid column"
  defp human_error(:column_full), do: "That column is full"
  defp human_error(:unknown_player), do: "Unknown player"
  defp human_error(:game_over), do: "The game is already over"
  defp human_error(_reason), do: "Unexpected error"

  defp role_label("spectator"), do: "Spectator"
  defp role_label(role), do: "#{String.capitalize(role)} player"

  defp badge_class("spectator"), do: "spectator"
  defp badge_class(role), do: role

  defp blank_board do
    List.duplicate(List.duplicate(nil, 7), 6)
  end

  defp broadcast_state(game) do
    Endpoint.broadcast!(topic(game.id), "state_updated", %{
      "state" => ConnectFourPayload.state(game)
    })
  end

  defp subscribe_topic(topic) do
    case Endpoint.subscribe(topic) do
      :ok -> :ok
      {:error, {:already_registered, _pid}} -> :ok
    end
  end

  defp topic(room_id), do: "connect_four:" <> room_id
end
