defmodule TestElixir.ConnectFour do
  @moduledoc """
  Pure Connect Four game rules.
  """

  @column_count 7
  @row_count 6
  @initial_columns [[], [], [], [], [], [], []]

  @enforce_keys [:id]
  defstruct id: nil,
            players: %{},
            spectators: [],
            connections: %{},
            columns: @initial_columns,
            status: :waiting_for_player,
            turn: :red,
            winner: nil

  @type color :: :red | :yellow
  @type role :: color() | :spectator
  @type status :: :waiting_for_player | :ready | :paused | :won | :draw
  @type player_id :: String.t()
  @type column :: non_neg_integer()
  @type connection_status :: :connected | :disconnected
  @type move_error ::
          :waiting_for_opponent
          | :waiting_for_reconnect
          | :game_over
          | :unknown_player
          | :spectator_cannot_play
          | :not_your_turn
          | :invalid_column
          | :column_full

  @type t :: %__MODULE__{
          id: String.t(),
          players: %{player_id() => color()},
          spectators: [player_id()],
          connections: %{player_id() => connection_status()},
          columns: [[color()]],
          status: status(),
          turn: color(),
          winner: color() | nil
        }

  @spec new(String.t()) :: t()
  def new(id) when is_binary(id) do
    %__MODULE__{id: id}
  end

  @spec join(t(), player_id()) :: {:ok, t(), role()}
  def join(%__MODULE__{} = game, player_id) when is_binary(player_id) do
    cond do
      Map.has_key?(game.players, player_id) ->
        {:ok, reconnect(game, player_id), game.players[player_id]}

      player_id in game.spectators ->
        {:ok, reconnect(game, player_id), :spectator}

      true ->
        do_join(game, player_id)
    end
  end

  @spec disconnect(t(), player_id()) :: {:ok, t()} | {:error, :unknown_player}
  def disconnect(%__MODULE__{} = game, player_id) when is_binary(player_id) do
    if participant?(game, player_id) do
      updated =
        game
        |> put_connection(player_id, :disconnected)
        |> refresh_status()

      {:ok, updated}
    else
      {:error, :unknown_player}
    end
  end

  @spec drop_disc(t(), player_id(), column()) :: {:ok, t()} | {:error, move_error()}
  def drop_disc(%__MODULE__{status: :waiting_for_player}, _player_id, _column) do
    {:error, :waiting_for_opponent}
  end

  def drop_disc(%__MODULE__{status: :paused}, _player_id, _column) do
    {:error, :waiting_for_reconnect}
  end

  def drop_disc(%__MODULE__{status: status}, _player_id, _column) when status in [:won, :draw] do
    {:error, :game_over}
  end

  def drop_disc(%__MODULE__{} = game, player_id, column) when is_binary(player_id) do
    with {:ok, color} <- fetch_color(game, player_id),
         :ok <- validate_turn(game, color),
         :ok <- validate_column(column),
         {:ok, columns, row_index} <- place_disc(game.columns, column, color) do
      updated =
        game
        |> Map.put(:columns, columns)
        |> finish_turn(color, column, row_index)

      {:ok, updated}
    end
  end

  @spec board_rows(t()) :: [[color() | nil]]
  def board_rows(%__MODULE__{columns: columns}) do
    for row_index <- (@row_count - 1)..0//-1 do
      for column_index <- 0..(@column_count - 1) do
        cell_at(columns, column_index, row_index)
      end
    end
  end

  defp do_join(%__MODULE__{players: players} = game, player_id) when map_size(players) == 0 do
    updated =
      %__MODULE__{
        game
        | players: Map.put(players, player_id, :red),
          connections: Map.put(game.connections, player_id, :connected)
      }

    {:ok, updated, :red}
  end

  defp do_join(%__MODULE__{players: players} = game, player_id) when map_size(players) == 1 do
    updated =
      %__MODULE__{
        game
        | players: Map.put(players, player_id, :yellow),
          connections: Map.put(game.connections, player_id, :connected),
          status: :ready
      }

    {:ok, updated, :yellow}
  end

  defp do_join(%__MODULE__{} = game, player_id) do
    updated =
      game
      |> put_spectator(player_id)
      |> put_connection(player_id, :connected)
      |> refresh_status()

    {:ok, updated, :spectator}
  end

  defp fetch_color(%__MODULE__{players: players, spectators: spectators}, player_id) do
    case Map.fetch(players, player_id) do
      {:ok, color} ->
        {:ok, color}

      :error ->
        if player_id in spectators do
          {:error, :spectator_cannot_play}
        else
          {:error, :unknown_player}
        end
    end
  end

  defp validate_turn(%__MODULE__{turn: turn}, turn), do: :ok
  defp validate_turn(%__MODULE__{}, _color), do: {:error, :not_your_turn}

  defp validate_column(column) when is_integer(column) and column >= 0 and column < @column_count,
    do: :ok

  defp validate_column(_column), do: {:error, :invalid_column}

  defp place_disc(columns, column_index, color) do
    column = Enum.at(columns, column_index)

    if length(column) >= @row_count do
      {:error, :column_full}
    else
      row_index = length(column)
      updated_column = column ++ [color]
      {:ok, List.replace_at(columns, column_index, updated_column), row_index}
    end
  end

  defp finish_turn(%__MODULE__{} = game, color, column_index, row_index) do
    cond do
      winning_move?(game.columns, column_index, row_index, color) ->
        %__MODULE__{game | status: :won, winner: color}

      draw?(game.columns) ->
        %__MODULE__{game | status: :draw}

      true ->
        %__MODULE__{game | turn: next_turn(color)}
    end
  end

  defp winning_move?(columns, column_index, row_index, color) do
    Enum.any?([{1, 0}, {0, 1}, {1, 1}, {1, -1}], fn {dx, dy} ->
      count_connected(columns, column_index, row_index, dx, dy, color) >= 4
    end)
  end

  defp count_connected(columns, column_index, row_index, dx, dy, color) do
    1 +
      count_direction(columns, column_index, row_index, dx, dy, color) +
      count_direction(columns, column_index, row_index, -dx, -dy, color)
  end

  defp count_direction(columns, column_index, row_index, dx, dy, color) do
    next_column = column_index + dx
    next_row = row_index + dy

    if cell_at(columns, next_column, next_row) == color do
      1 + count_direction(columns, next_column, next_row, dx, dy, color)
    else
      0
    end
  end

  defp draw?(columns) do
    Enum.all?(columns, &(length(&1) == @row_count))
  end

  defp next_turn(:red), do: :yellow
  defp next_turn(:yellow), do: :red

  defp participant?(%__MODULE__{} = game, player_id) do
    Map.has_key?(game.players, player_id) or player_id in game.spectators
  end

  defp put_connection(%__MODULE__{} = game, player_id, status) do
    %__MODULE__{game | connections: Map.put(game.connections, player_id, status)}
  end

  defp put_spectator(%__MODULE__{} = game, player_id) do
    %__MODULE__{game | spectators: [player_id | game.spectators]}
  end

  defp reconnect(%__MODULE__{} = game, player_id) do
    game
    |> put_connection(player_id, :connected)
    |> refresh_status()
  end

  defp refresh_status(%__MODULE__{status: status} = game) when status in [:won, :draw] do
    game
  end

  defp refresh_status(%__MODULE__{players: players} = game) when map_size(players) < 2 do
    %__MODULE__{game | status: :waiting_for_player}
  end

  defp refresh_status(%__MODULE__{} = game) do
    if all_connected?(game) do
      %__MODULE__{game | status: :ready}
    else
      %__MODULE__{game | status: :paused}
    end
  end

  defp all_connected?(%__MODULE__{players: players, connections: connections}) do
    Enum.all?(Map.keys(players), fn player_id ->
      Map.get(connections, player_id) == :connected
    end)
  end

  defp cell_at(_columns, column_index, row_index)
       when column_index < 0 or column_index >= @column_count or row_index < 0 or
              row_index >= @row_count do
    nil
  end

  defp cell_at(columns, column_index, row_index) do
    columns
    |> Enum.at(column_index, [])
    |> Enum.at(row_index)
  end
end
