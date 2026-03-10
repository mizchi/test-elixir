defmodule TestElixir.Wasm.Bench do
  alias TestElixir.Wasm.Build
  alias TestElixir.Wasm.PortRunner
  alias TestElixir.Wasm.WasmexRunner

  def run do
    paths = Build.ensure_built!()
    fib_input = env_integer!("FIB_INPUT", 20)
    fib_expected = fib(fib_input)
    warmup = env_float!("BENCH_WARMUP_S", 1.0)
    time = env_float!("BENCH_TIME_S", 3.0)
    memory_time = env_float!("BENCH_MEMORY_TIME_S", 1.0)

    IO.puts("Benchmarking Wasm runtimes with #{paths.module_path}")
    IO.puts("fib input: #{fib_input}")

    Benchee.run(
      %{
        "wasmex/cold_add" => fn ->
          with_runner(WasmexRunner, paths.module_path, fn runner ->
            expect_ok!(WasmexRunner.add(runner, 20, 22), 42)
          end)
        end,
        "port/cold_add" => fn ->
          with_runner(PortRunner, paths.module_path, fn runner ->
            expect_ok!(PortRunner.add(runner, 20, 22), 42)
          end)
        end
      },
      memory_time: memory_time,
      time: time,
      warmup: warmup
    )

    {:ok, wasmex_runner} = WasmexRunner.start_link(module_path: paths.module_path)
    {:ok, port_runner} = PortRunner.start_link(module_path: paths.module_path)

    try do
      Benchee.run(
        %{
          "wasmex/hot_add" => fn ->
            expect_ok!(WasmexRunner.add(wasmex_runner, 20, 22), 42)
          end,
          "port/hot_add" => fn ->
            expect_ok!(PortRunner.add(port_runner, 20, 22), 42)
          end,
          "wasmex/hot_fib" => fn ->
            expect_ok!(WasmexRunner.fib(wasmex_runner, fib_input), fib_expected)
          end,
          "port/hot_fib" => fn ->
            expect_ok!(PortRunner.fib(port_runner, fib_input), fib_expected)
          end
        },
        memory_time: memory_time,
        time: time,
        warmup: warmup
      )
    after
      if Process.alive?(wasmex_runner), do: GenServer.stop(wasmex_runner)
      if Process.alive?(port_runner), do: GenServer.stop(port_runner)
    end
  end

  defp with_runner(module, module_path, fun) do
    {:ok, runner} = module.start_link(module_path: module_path)

    try do
      fun.(runner)
    after
      if Process.alive?(runner), do: GenServer.stop(runner)
    end
  end

  defp expect_ok!({:ok, value}, expected) when value == expected, do: value

  defp expect_ok!(result, expected) do
    raise "unexpected benchmark result #{inspect(result)}, expected #{inspect(expected)}"
  end

  defp env_integer!(name, default) do
    case System.get_env(name) do
      nil -> default
      value -> String.to_integer(value)
    end
  end

  defp env_float!(name, default) do
    case System.get_env(name) do
      nil ->
        default

      value ->
        case Float.parse(value) do
          {parsed, ""} ->
            parsed

          _other ->
            raise "expected #{name} to be a float-compatible number, got #{inspect(value)}"
        end
    end
  end

  defp fib(n) when n < 2, do: n
  defp fib(n), do: fib(n - 1) + fib(n - 2)
end

TestElixir.Wasm.Bench.run()
