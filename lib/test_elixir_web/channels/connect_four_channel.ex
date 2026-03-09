defmodule TestElixirWeb.ConnectFourChannel do
  use TestElixirWeb, :channel

  alias TestElixir.ConnectFour.Server
  alias TestElixirWeb.ConnectFourPayload

  @impl true
  def join("connect_four:" <> room_id, _payload, socket) do
    with {:ok, game, color} <- Server.join_room(room_id, socket.assigns.player_id) do
      socket = assign(socket, :room_id, room_id)
      send(self(), {:broadcast_state, game})

      {:ok, %{player_color: Atom.to_string(color), state: ConnectFourPayload.state(game)}, socket}
    else
      {:error, reason} ->
        {:error, %{"detail" => error_detail(reason)}}
    end
  end

  @impl true
  def handle_in("drop_token", %{"column" => column}, socket) do
    with {:ok, parsed_column} <- parse_column(column),
         {:ok, game} <-
           Server.drop_disc(socket.assigns.room_id, socket.assigns.player_id, parsed_column) do
      broadcast!(socket, "state_updated", %{"state" => ConnectFourPayload.state(game)})
      {:reply, :ok, socket}
    else
      {:error, reason} ->
        {:reply, {:error, %{"detail" => error_detail(reason)}}, socket}
    end
  end

  def handle_in("drop_token", _payload, socket) do
    {:reply, {:error, %{"detail" => "invalid_column"}}, socket}
  end

  @impl true
  def handle_info({:broadcast_state, game}, socket) do
    broadcast_from!(socket, "state_updated", %{"state" => ConnectFourPayload.state(game)})
    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    case {socket.assigns[:room_id], socket.assigns[:player_id]} do
      {room_id, player_id} when is_binary(room_id) and is_binary(player_id) ->
        case Server.disconnect_player(room_id, player_id) do
          {:ok, game} ->
            TestElixirWeb.Endpoint.broadcast!(
              "connect_four:" <> room_id,
              "state_updated",
              %{"state" => ConnectFourPayload.state(game)}
            )

          _ ->
            :ok
        end

      _ ->
        :ok
    end

    :ok
  end

  defp parse_column(column) when is_integer(column), do: {:ok, column}

  defp parse_column(column) when is_binary(column) do
    case Integer.parse(column) do
      {parsed, ""} -> {:ok, parsed}
      _ -> {:error, :invalid_column}
    end
  end

  defp parse_column(_column), do: {:error, :invalid_column}

  defp error_detail(reason), do: Atom.to_string(reason)
end
