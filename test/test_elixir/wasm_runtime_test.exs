defmodule TestElixir.WasmRuntimeTest do
  use ExUnit.Case, async: false

  alias TestElixir.Wasm.Build
  alias TestElixir.Wasm.PortRunner
  alias TestElixir.Wasm.WasmexRunner

  setup_all do
    paths = Build.ensure_built!()

    assert File.exists?(paths.module_path)
    assert File.exists?(paths.host_binary_path)

    {:ok, paths: paths}
  end

  test "both runtimes execute the same wasm exports" do
    {:ok, wasmex} = WasmexRunner.start_link(module_path: Build.paths().module_path)
    {:ok, port} = PortRunner.start_link(module_path: Build.paths().module_path)

    on_exit(fn ->
      if Process.alive?(wasmex), do: GenServer.stop(wasmex)
      if Process.alive?(port), do: GenServer.stop(port)
    end)

    assert {:ok, 42} = WasmexRunner.add(wasmex, 20, 22)
    assert {:ok, 42} = PortRunner.add(port, 20, 22)

    assert {:ok, 55} = WasmexRunner.fib(wasmex, 10)
    assert {:ok, 55} = PortRunner.fib(port, 10)
  end

  test "port runtime rejects unsupported functions" do
    {:ok, port} = PortRunner.start_link(module_path: Build.paths().module_path)

    on_exit(fn ->
      if Process.alive?(port), do: GenServer.stop(port)
    end)

    assert {:error, :unsupported_function} = PortRunner.call(port, "mul", [2, 3])
  end
end
