defmodule Devcontainers.Services.Redis do
  @moduledoc """
  Service handler for Redis containers.

  Matches images: `redis:*`, `bitnami/redis:*`

  ## Environment Variables

  Reads the following environment variables from the compose service:

  - `REDIS_PASSWORD` - Password (optional)

  ## Example compose.yml

      services:
        redis:
          image: redis:7
          ports:
            - "6379"

      # Or with password
      services:
        redis:
          image: redis:7
          command: redis-server --requirepass secret
          environment:
            REDIS_PASSWORD: secret
          ports:
            - "6379"

  """

  @behaviour Devcontainers.Services.Service

  alias Devcontainers.Services.ConnectionDetails
  alias Devcontainers.Docker.HealthCheck

  @impl true
  def match?(image) do
    String.match?(image, ~r/^redis(:\S+)?$/) or
      String.match?(image, ~r/^bitnami\/redis(:\S+)?$/)
  end

  @impl true
  def connection_details(service, container_info) do
    env = service.environment
    password = Map.get(env, "REDIS_PASSWORD")

    %ConnectionDetails{
      type: :redis,
      host: container_info.host,
      port: Map.get(container_info.ports, 6379, container_info.port),
      password: password
    }
  end

  @impl true
  def health_check_port(_service), do: 6379

  @impl true
  def service_type, do: :redis

  @impl true
  def ready?(host, port, opts) do
    # First check TCP
    if HealthCheck.tcp_ready?(host, port, opts) do
      # Then try PING command
      redis_ping(host, port)
    else
      false
    end
  end

  defp redis_ping(host, port) do
    host_charlist = to_charlist(host)

    case :gen_tcp.connect(host_charlist, port, [:binary, active: false], 1000) do
      {:ok, socket} ->
        :gen_tcp.send(socket, "PING\r\n")

        result =
          case :gen_tcp.recv(socket, 0, 1000) do
            {:ok, "+PONG\r\n"} -> true
            {:ok, "-NOAUTH" <> _} -> true
            _ -> false
          end

        :gen_tcp.close(socket)
        result

      {:error, _} ->
        false
    end
  rescue
    _ -> false
  end
end
