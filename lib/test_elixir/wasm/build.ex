defmodule TestElixir.Wasm.Build do
  @moduledoc false

  @type paths :: %{
          module_path: String.t(),
          host_binary_path: String.t(),
          host_crate_dir: String.t()
        }

  @spec paths() :: paths()
  def paths do
    project_root = Path.expand("../../..", __DIR__)
    host_crate_dir = Path.join(project_root, "native/wasmtime_host")

    %{
      module_path: Path.join(project_root, "priv/wasm/sample.wat"),
      host_binary_path: Path.join([host_crate_dir, "target", "release", host_binary_name()]),
      host_crate_dir: host_crate_dir
    }
  end

  @spec ensure_built!() :: paths()
  def ensure_built! do
    current_paths = paths()

    unless File.exists?(current_paths.module_path) do
      raise "missing wasm module fixture at #{current_paths.module_path}"
    end

    if stale_host?(current_paths) do
      build_host!(current_paths.host_crate_dir)
    end

    unless File.exists?(current_paths.host_binary_path) do
      raise "missing wasmtime host binary at #{current_paths.host_binary_path}"
    end

    current_paths
  end

  defp stale_host?(paths) do
    binary_mtime =
      case File.stat(paths.host_binary_path, time: :posix) do
        {:ok, stat} -> stat.mtime
        {:error, _reason} -> nil
      end

    source_paths = [
      Path.join(paths.host_crate_dir, "Cargo.toml")
      | Path.wildcard(Path.join(paths.host_crate_dir, "src/**/*"))
    ]

    is_nil(binary_mtime) or
      Enum.any?(source_paths, fn path ->
        case File.stat(path, time: :posix) do
          {:ok, stat} -> stat.mtime > binary_mtime
          {:error, _reason} -> true
        end
      end)
  end

  defp build_host!(host_crate_dir) do
    cargo = System.find_executable("cargo") || raise "cargo executable not found"

    {output, status} =
      System.cmd(cargo, ["build", "--release"], cd: host_crate_dir, stderr_to_stdout: true)

    if status != 0 do
      raise """
      failed to build native wasmtime host:

      #{output}
      """
    end
  end

  defp host_binary_name do
    case :os.type() do
      {:win32, _os_name} -> "wasmtime_host.exe"
      _other -> "wasmtime_host"
    end
  end
end
