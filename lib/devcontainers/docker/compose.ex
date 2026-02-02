defmodule Devcontainers.Docker.Compose do
  @moduledoc """
  Docker Compose CLI wrapper.

  Provides functions to interact with Docker Compose, supporting both the modern
  `docker compose` (v2) and legacy `docker-compose` (v1) CLI variants.

  ## Examples

      # Check if Docker Compose is available
      iex> Devcontainers.Docker.Compose.available?()
      true

      # Start services
      iex> Devcontainers.Docker.Compose.up(file: "compose.yml", detach: true)
      :ok

      # Get running containers
      iex> Devcontainers.Docker.Compose.ps(file: "compose.yml")
      {:ok, [%{"Name" => "myapp-db-1", "State" => "running", ...}]}

  """

  require Logger

  @type compose_opts :: [
          file: String.t(),
          project_name: String.t() | nil,
          profiles: [String.t()],
          detach: boolean(),
          wait: boolean(),
          volumes: boolean()
        ]

  @doc """
  Checks if Docker and Docker Compose are available.

  Returns `true` if both `docker` and either `docker compose` or `docker-compose`
  are available on the system.

  ## Examples

      iex> Devcontainers.Docker.Compose.available?()
      true

  """
  @spec available?() :: boolean()
  def available? do
    docker_available?() and compose_available?()
  end

  @doc """
  Checks if Docker daemon is running and accessible.
  """
  @spec docker_available?() :: boolean()
  def docker_available? do
    case System.cmd("docker", ["info"], stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  @doc """
  Checks if Docker Compose is available (either v1 or v2).
  """
  @spec compose_available?() :: boolean()
  def compose_available? do
    compose_command() != nil
  end

  @doc """
  Returns the Docker Compose command to use.

  Prefers `docker compose` (v2) over `docker-compose` (v1).
  Returns `nil` if neither is available.
  """
  @spec compose_command() :: {:plugin, String.t()} | {:standalone, String.t()} | nil
  def compose_command do
    cond do
      compose_v2_available?() -> {:plugin, "docker"}
      compose_v1_available?() -> {:standalone, "docker-compose"}
      true -> nil
    end
  end

  defp compose_v2_available? do
    case System.cmd("docker", ["compose", "version"], stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  defp compose_v1_available? do
    case System.cmd("docker-compose", ["version"], stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  @doc """
  Starts services defined in the compose file.

  ## Options

  - `:file` - Path to compose file (required)
  - `:project_name` - Project name for Docker Compose
  - `:profiles` - List of profiles to activate
  - `:detach` - Run in detached mode (default: `true`)
  - `:wait` - Wait for services to be healthy (default: `true`)

  ## Examples

      iex> Devcontainers.Docker.Compose.up(file: "compose.yml")
      :ok

      iex> Devcontainers.Docker.Compose.up(file: "compose.yml", profiles: ["dev"])
      :ok

  """
  @spec up(compose_opts()) :: :ok | {:error, String.t()}
  def up(opts) do
    file = Keyword.fetch!(opts, :file)
    project_name = Keyword.get(opts, :project_name)
    profiles = Keyword.get(opts, :profiles, [])
    detach = Keyword.get(opts, :detach, true)
    wait = Keyword.get(opts, :wait, true)

    args =
      build_base_args(file, project_name, profiles) ++
        ["up"] ++
        if(detach, do: ["-d"], else: []) ++
        if(wait, do: ["--wait"], else: [])

    run_compose(args)
  end

  @doc """
  Stops running services without removing them.

  ## Options

  - `:file` - Path to compose file (required)
  - `:project_name` - Project name for Docker Compose
  - `:profiles` - List of profiles to activate

  ## Examples

      iex> Devcontainers.Docker.Compose.stop(file: "compose.yml")
      :ok

  """
  @spec stop(compose_opts()) :: :ok | {:error, String.t()}
  def stop(opts) do
    file = Keyword.fetch!(opts, :file)
    project_name = Keyword.get(opts, :project_name)
    profiles = Keyword.get(opts, :profiles, [])

    args = build_base_args(file, project_name, profiles) ++ ["stop"]
    run_compose(args)
  end

  @doc """
  Stops and removes containers, networks, and optionally volumes.

  ## Options

  - `:file` - Path to compose file (required)
  - `:project_name` - Project name for Docker Compose
  - `:profiles` - List of profiles to activate
  - `:volumes` - Also remove volumes (default: `false`)

  ## Examples

      iex> Devcontainers.Docker.Compose.down(file: "compose.yml")
      :ok

      iex> Devcontainers.Docker.Compose.down(file: "compose.yml", volumes: true)
      :ok

  """
  @spec down(compose_opts()) :: :ok | {:error, String.t()}
  def down(opts) do
    file = Keyword.fetch!(opts, :file)
    project_name = Keyword.get(opts, :project_name)
    profiles = Keyword.get(opts, :profiles, [])
    volumes = Keyword.get(opts, :volumes, false)

    args =
      build_base_args(file, project_name, profiles) ++
        ["down"] ++
        if(volumes, do: ["-v"], else: [])

    run_compose(args)
  end

  @doc """
  Lists containers for the compose project.

  Returns a list of container information maps parsed from JSON output.

  ## Options

  - `:file` - Path to compose file (required)
  - `:project_name` - Project name for Docker Compose
  - `:profiles` - List of profiles to activate

  ## Examples

      iex> Devcontainers.Docker.Compose.ps(file: "compose.yml")
      {:ok, [
        %{
          "Name" => "myapp-db-1",
          "Service" => "db",
          "State" => "running",
          "Publishers" => [%{"PublishedPort" => 5432, "TargetPort" => 5432}]
        }
      ]}

  """
  @spec ps(compose_opts()) :: {:ok, [map()]} | {:error, String.t()}
  def ps(opts) do
    file = Keyword.fetch!(opts, :file)
    project_name = Keyword.get(opts, :project_name)
    profiles = Keyword.get(opts, :profiles, [])

    args = build_base_args(file, project_name, profiles) ++ ["ps", "--format", "json"]

    case run_compose_with_output(args) do
      {:ok, output} -> parse_ps_output(output)
      error -> error
    end
  end

  @doc """
  Gets the published port for a service's container port.

  ## Examples

      iex> Devcontainers.Docker.Compose.port("compose.yml", "db", 5432)
      {:ok, 32768}

  """
  @spec port(String.t(), String.t(), non_neg_integer(), keyword()) ::
          {:ok, non_neg_integer()} | {:error, String.t()}
  def port(file, service, container_port, opts \\ []) do
    project_name = Keyword.get(opts, :project_name)
    profiles = Keyword.get(opts, :profiles, [])

    args =
      build_base_args(file, project_name, profiles) ++
        ["port", service, to_string(container_port)]

    case run_compose_with_output(args) do
      {:ok, output} ->
        case parse_port_output(output) do
          {:ok, port} -> {:ok, port}
          :error -> {:error, "Could not parse port output: #{output}"}
        end

      error ->
        error
    end
  end

  # Private functions

  defp build_base_args(file, project_name, profiles) do
    args = ["-f", file]

    args =
      if project_name do
        args ++ ["-p", project_name]
      else
        args
      end

    Enum.reduce(profiles, args, fn profile, acc ->
      acc ++ ["--profile", profile]
    end)
  end

  defp run_compose(args) do
    case compose_command() do
      {:plugin, docker} ->
        full_args = ["compose" | args]
        Logger.debug("Running: #{docker} #{Enum.join(full_args, " ")}")

        case System.cmd(docker, full_args, stderr_to_stdout: true) do
          {_, 0} -> :ok
          {output, _} -> {:error, output}
        end

      {:standalone, compose} ->
        Logger.debug("Running: #{compose} #{Enum.join(args, " ")}")

        case System.cmd(compose, args, stderr_to_stdout: true) do
          {_, 0} -> :ok
          {output, _} -> {:error, output}
        end

      nil ->
        {:error, "Docker Compose is not available"}
    end
  end

  defp run_compose_with_output(args) do
    case compose_command() do
      {:plugin, docker} ->
        full_args = ["compose" | args]
        Logger.debug("Running: #{docker} #{Enum.join(full_args, " ")}")

        case System.cmd(docker, full_args, stderr_to_stdout: true) do
          {output, 0} -> {:ok, String.trim(output)}
          {output, _} -> {:error, output}
        end

      {:standalone, compose} ->
        Logger.debug("Running: #{compose} #{Enum.join(args, " ")}")

        case System.cmd(compose, args, stderr_to_stdout: true) do
          {output, 0} -> {:ok, String.trim(output)}
          {output, _} -> {:error, output}
        end

      nil ->
        {:error, "Docker Compose is not available"}
    end
  end

  defp parse_ps_output(""), do: {:ok, []}

  defp parse_ps_output(output) do
    # Docker Compose v2 outputs one JSON object per line
    output
    |> String.split("\n", trim: true)
    |> Enum.reduce_while({:ok, []}, fn line, {:ok, acc} ->
      case Jason.decode(line) do
        {:ok, container} -> {:cont, {:ok, [container | acc]}}
        {:error, _} -> {:halt, {:error, "Failed to parse JSON: #{line}"}}
      end
    end)
    |> case do
      {:ok, containers} -> {:ok, Enum.reverse(containers)}
      error -> error
    end
  end

  defp parse_port_output(output) do
    # Output format: "0.0.0.0:32768" or "[::]:32768"
    case Regex.run(~r/:(\d+)$/, output) do
      [_, port_str] -> {:ok, String.to_integer(port_str)}
      nil -> :error
    end
  end
end
