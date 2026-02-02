defmodule Devcontainers.Docker.HealthCheck do
  @moduledoc """
  Health checking utilities for Docker containers.

  Provides functions to check if services are ready to accept connections,
  with configurable timeouts and retry logic.

  ## Examples

      # Wait for PostgreSQL to be ready
      iex> Devcontainers.Docker.HealthCheck.wait_for_tcp("localhost", 5432, timeout: 30_000)
      :ok

      # Check if a port is reachable
      iex> Devcontainers.Docker.HealthCheck.tcp_ready?("localhost", 5432)
      true

  """

  require Logger

  @default_timeout 60_000
  @default_interval 500

  @doc """
  Checks if a TCP port is accepting connections.

  ## Examples

      iex> Devcontainers.Docker.HealthCheck.tcp_ready?("localhost", 5432)
      true

      iex> Devcontainers.Docker.HealthCheck.tcp_ready?("localhost", 99999)
      false

  """
  @spec tcp_ready?(String.t(), non_neg_integer(), keyword()) :: boolean()
  def tcp_ready?(host, port, opts \\ []) do
    timeout = Keyword.get(opts, :connect_timeout, 1000)

    host_charlist = to_charlist(host)

    case :gen_tcp.connect(host_charlist, port, [:binary, active: false], timeout) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        true

      {:error, _} ->
        false
    end
  end

  @doc """
  Waits for a TCP port to become ready.

  Repeatedly attempts to connect until successful or timeout is reached.

  ## Options

  - `:timeout` - Maximum time to wait in milliseconds (default: 60000)
  - `:interval` - Time between attempts in milliseconds (default: 500)
  - `:connect_timeout` - Timeout for each connection attempt (default: 1000)

  ## Examples

      iex> Devcontainers.Docker.HealthCheck.wait_for_tcp("localhost", 5432)
      :ok

      iex> Devcontainers.Docker.HealthCheck.wait_for_tcp("localhost", 5432, timeout: 5000)
      {:error, :timeout}

  """
  @spec wait_for_tcp(String.t(), non_neg_integer(), keyword()) :: :ok | {:error, :timeout}
  def wait_for_tcp(host, port, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    interval = Keyword.get(opts, :interval, @default_interval)
    connect_timeout = Keyword.get(opts, :connect_timeout, 1000)

    deadline = System.monotonic_time(:millisecond) + timeout

    Logger.debug("Waiting for #{host}:#{port} (timeout: #{timeout}ms)")

    wait_loop(host, port, deadline, interval, connect_timeout)
  end

  @doc """
  Waits for multiple services to become ready.

  Takes a list of `{host, port}` tuples and waits for all of them.

  ## Options

  Same as `wait_for_tcp/3`.

  ## Examples

      iex> services = [{"localhost", 5432}, {"localhost", 6379}]
      iex> Devcontainers.Docker.HealthCheck.wait_for_all(services)
      :ok

  """
  @spec wait_for_all([{String.t(), non_neg_integer()}], keyword()) :: :ok | {:error, term()}
  def wait_for_all(services, opts \\ []) do
    # Run health checks in parallel
    tasks =
      Enum.map(services, fn {host, port} ->
        Task.async(fn ->
          case wait_for_tcp(host, port, opts) do
            :ok -> {:ok, {host, port}}
            error -> {:error, {host, port}, error}
          end
        end)
      end)

    timeout = Keyword.get(opts, :timeout, @default_timeout)
    results = Task.await_many(tasks, timeout + 1000)

    failed =
      results
      |> Enum.filter(fn
        {:error, _, _} -> true
        _ -> false
      end)

    case failed do
      [] -> :ok
      errors -> {:error, format_errors(errors)}
    end
  end

  @doc """
  Performs an HTTP health check.

  Requires the optional `req` dependency.

  ## Options

  - `:method` - HTTP method (default: `:get`)
  - `:path` - URL path (default: `"/"`)
  - `:expected_status` - Expected HTTP status code (default: `200`)
  - `:timeout` - Request timeout in milliseconds (default: `5000`)

  ## Examples

      iex> Devcontainers.Docker.HealthCheck.http_ready?("localhost", 8080)
      true

      iex> Devcontainers.Docker.HealthCheck.http_ready?("localhost", 8080, path: "/health")
      true

  """
  @spec http_ready?(String.t(), non_neg_integer(), keyword()) :: boolean()
  def http_ready?(host, port, opts \\ []) do
    if Code.ensure_loaded?(Req) do
      method = Keyword.get(opts, :method, :get)
      path = Keyword.get(opts, :path, "/")
      expected_status = Keyword.get(opts, :expected_status, 200)
      timeout = Keyword.get(opts, :timeout, 5000)

      url = "http://#{host}:#{port}#{path}"

      try do
        case apply(Req, :request, [[method: method, url: url, receive_timeout: timeout]]) do
          {:ok, %{status: ^expected_status}} -> true
          _ -> false
        end
      rescue
        _ -> false
      end
    else
      Logger.warning("HTTP health check requires the :req dependency")
      # Fall back to TCP check
      tcp_ready?(host, port, opts)
    end
  end

  @doc """
  Waits for an HTTP endpoint to become ready.

  ## Options

  Same as `http_ready?/3` plus:
  - `:timeout` - Maximum time to wait in milliseconds (default: 60000)
  - `:interval` - Time between attempts in milliseconds (default: 500)

  ## Examples

      iex> Devcontainers.Docker.HealthCheck.wait_for_http("localhost", 8080, path: "/health")
      :ok

  """
  @spec wait_for_http(String.t(), non_neg_integer(), keyword()) :: :ok | {:error, :timeout}
  def wait_for_http(host, port, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    interval = Keyword.get(opts, :interval, @default_interval)

    deadline = System.monotonic_time(:millisecond) + timeout

    Logger.debug("Waiting for HTTP #{host}:#{port} (timeout: #{timeout}ms)")

    wait_http_loop(host, port, deadline, interval, opts)
  end

  # Private functions

  defp wait_loop(host, port, deadline, interval, connect_timeout) do
    if tcp_ready?(host, port, connect_timeout: connect_timeout) do
      Logger.debug("#{host}:#{port} is ready")
      :ok
    else
      now = System.monotonic_time(:millisecond)

      if now >= deadline do
        Logger.warning("Timeout waiting for #{host}:#{port}")
        {:error, :timeout}
      else
        Process.sleep(interval)
        wait_loop(host, port, deadline, interval, connect_timeout)
      end
    end
  end

  defp wait_http_loop(host, port, deadline, interval, opts) do
    if http_ready?(host, port, opts) do
      Logger.debug("HTTP #{host}:#{port} is ready")
      :ok
    else
      now = System.monotonic_time(:millisecond)

      if now >= deadline do
        Logger.warning("Timeout waiting for HTTP #{host}:#{port}")
        {:error, :timeout}
      else
        Process.sleep(interval)
        wait_http_loop(host, port, deadline, interval, opts)
      end
    end
  end

  defp format_errors(errors) do
    errors
    |> Enum.map(fn {:error, {host, port}, _} -> "#{host}:#{port}" end)
    |> Enum.join(", ")
    |> then(&"Failed to connect to: #{&1}")
  end
end
