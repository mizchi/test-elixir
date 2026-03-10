defmodule TestElixir.Wasm.PortRunner do
  use GenServer

  alias TestElixir.Wasm.Build

  @type option :: {:module_path, String.t()}
  @type call_result ::
          {:ok, integer()} | {:error, atom() | String.t() | {:port_exited, integer()}}

  @spec start_link([option()]) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @spec add(GenServer.server(), integer(), integer()) :: call_result()
  def add(server, left, right) do
    call(server, "add", [left, right])
  end

  @spec fib(GenServer.server(), integer()) :: call_result()
  def fib(server, n) do
    call(server, "fib", [n])
  end

  @spec call(GenServer.server(), String.t(), [integer()]) :: call_result()
  def call(server, function_name, args) do
    GenServer.call(server, {:call, function_name, args}, 10_000)
  end

  @impl true
  def init(opts) do
    paths = Build.ensure_built!()
    module_path = Keyword.get(opts, :module_path, paths.module_path)

    port =
      Port.open(
        {:spawn_executable, paths.host_binary_path},
        [:binary, :exit_status, :use_stdio, :stderr_to_stdout, {:packet, 4}, args: [module_path]]
      )

    {:ok, %{pending_from: nil, port: port}}
  end

  @impl true
  def handle_call({:call, function_name, args}, from, %{pending_from: nil, port: port} = state) do
    payload = Jason.encode!(%{args: args, function: function_name})
    true = Port.command(port, payload)
    {:noreply, %{state | pending_from: from}}
  end

  def handle_call({:call, _function_name, _args}, _from, state) do
    {:reply, {:error, :busy}, state}
  end

  @impl true
  def handle_info({port, {:data, data}}, %{pending_from: from, port: port} = state)
      when not is_nil(from) do
    GenServer.reply(from, decode_response(data))
    {:noreply, %{state | pending_from: nil}}
  end

  def handle_info({port, {:exit_status, status}}, %{pending_from: from, port: port} = state) do
    if from do
      GenServer.reply(from, {:error, {:port_exited, status}})
    end

    {:stop, {:port_exited, status}, %{state | pending_from: nil}}
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, %{port: port}) do
    Port.close(port)
    :ok
  end

  defp decode_response(data) do
    case Jason.decode!(data) do
      %{"ok" => value} when is_integer(value) -> {:ok, value}
      %{"error" => "invalid_arguments"} -> {:error, :invalid_arguments}
      %{"error" => "unsupported_function"} -> {:error, :unsupported_function}
      %{"error" => reason} when is_binary(reason) -> {:error, reason}
    end
  end
end
