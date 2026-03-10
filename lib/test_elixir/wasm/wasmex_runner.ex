defmodule TestElixir.Wasm.WasmexRunner do
  use GenServer

  alias TestElixir.Wasm.Build

  @type option :: {:module_path, String.t()}
  @type call_result :: {:ok, integer()} | {:error, atom() | String.t()}

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
    GenServer.call(server, {:call, function_name, args})
  end

  @impl true
  def init(opts) do
    module_path = Keyword.get(opts, :module_path, Build.paths().module_path)
    bytes = File.read!(module_path)
    {:ok, instance} = Wasmex.start_link(%{bytes: bytes})
    {:ok, %{instance: instance}}
  end

  @impl true
  def handle_call({:call, function_name, args}, _from, %{instance: instance} = state) do
    {:reply, normalize_result(Wasmex.call_function(instance, function_name, args)), state}
  end

  defp normalize_result({:ok, values}) when is_list(values) do
    case List.flatten(values) do
      [value] when is_integer(value) -> {:ok, value}
      flattened -> {:error, "unexpected wasmex result #{inspect(flattened)}"}
    end
  end

  defp normalize_result({:error, reason}), do: {:error, normalize_reason(reason)}

  defp normalize_reason(%ArgumentError{}), do: :unsupported_function
  defp normalize_reason(%RuntimeError{message: message}) when is_binary(message), do: message
  defp normalize_reason(reason) when is_binary(reason), do: reason
  defp normalize_reason(reason), do: inspect(reason)
end
