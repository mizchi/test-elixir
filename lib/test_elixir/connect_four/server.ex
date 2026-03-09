defmodule TestElixir.ConnectFour.Server do
  @moduledoc """
  One GenServer per Connect Four room.
  """

  use GenServer

  alias TestElixir.ConnectFour

  @registry TestElixir.ConnectFour.Registry
  @supervisor TestElixir.ConnectFour.RoomSupervisor
  @room_id_bytes 6

  @type room_id :: String.t()

  @spec start_link(room_id()) :: GenServer.on_start()
  def start_link(room_id) when is_binary(room_id) do
    GenServer.start_link(__MODULE__, room_id, name: via(room_id))
  end

  @spec create_room() :: {:ok, room_id()} | {:error, term()}
  def create_room do
    room_id = generate_room_id()

    case DynamicSupervisor.start_child(@supervisor, {__MODULE__, room_id}) do
      {:ok, _pid} ->
        {:ok, room_id}

      {:error, {:already_started, _pid}} ->
        create_room()

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec state(room_id()) :: {:ok, ConnectFour.t()} | {:error, :not_found}
  def state(room_id) do
    with {:ok, pid} <- fetch_room(room_id) do
      {:ok, GenServer.call(pid, :state)}
    end
  end

  @spec join_room(room_id(), String.t()) ::
          {:ok, ConnectFour.t(), ConnectFour.role()} | {:error, :not_found}
  def join_room(room_id, player_id) do
    with {:ok, pid} <- fetch_room(room_id) do
      GenServer.call(pid, {:join, player_id})
    end
  end

  @spec drop_disc(room_id(), String.t(), integer()) ::
          {:ok, ConnectFour.t()} | {:error, :not_found | ConnectFour.move_error()}
  def drop_disc(room_id, player_id, column) do
    with {:ok, pid} <- fetch_room(room_id) do
      GenServer.call(pid, {:drop_disc, player_id, column})
    end
  end

  @spec disconnect_player(room_id(), String.t()) ::
          {:ok, ConnectFour.t()} | {:error, :not_found | :unknown_player}
  def disconnect_player(room_id, player_id) do
    with {:ok, pid} <- fetch_room(room_id) do
      GenServer.call(pid, {:disconnect, player_id})
    end
  end

  @impl true
  def init(room_id) do
    {:ok, ConnectFour.new(room_id)}
  end

  @impl true
  def handle_call(:state, _from, game) do
    {:reply, game, game}
  end

  def handle_call({:join, player_id}, _from, game) do
    {:ok, updated, role} = ConnectFour.join(game, player_id)
    {:reply, {:ok, updated, role}, updated}
  end

  def handle_call({:drop_disc, player_id, column}, _from, game) do
    case ConnectFour.drop_disc(game, player_id, column) do
      {:ok, updated} ->
        {:reply, {:ok, updated}, updated}

      {:error, reason} ->
        {:reply, {:error, reason}, game}
    end
  end

  def handle_call({:disconnect, player_id}, _from, game) do
    case ConnectFour.disconnect(game, player_id) do
      {:ok, updated} ->
        {:reply, {:ok, updated}, updated}

      {:error, reason} ->
        {:reply, {:error, reason}, game}
    end
  end

  defp fetch_room(room_id) do
    case Registry.lookup(@registry, room_id) do
      [{pid, _value}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  defp via(room_id) do
    {:via, Registry, {@registry, room_id}}
  end

  defp generate_room_id do
    @room_id_bytes
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
    |> binary_part(0, 8)
  end
end
