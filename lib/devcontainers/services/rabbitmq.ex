defmodule Devcontainers.Services.RabbitMQ do
  @moduledoc """
  Service handler for RabbitMQ containers.

  Matches images: `rabbitmq:*`

  ## Environment Variables

  Reads the following environment variables from the compose service:

  - `RABBITMQ_DEFAULT_USER` - Username (default: `"guest"`)
  - `RABBITMQ_DEFAULT_PASS` - Password (default: `"guest"`)
  - `RABBITMQ_DEFAULT_VHOST` - Virtual host (default: `"/"`)

  ## Ports

  - `5672` - AMQP port (used for connection)
  - `15672` - Management UI port

  ## Example compose.yml

      services:
        rabbitmq:
          image: rabbitmq:3-management
          environment:
            RABBITMQ_DEFAULT_USER: myapp
            RABBITMQ_DEFAULT_PASS: secret
          ports:
            - "5672"
            - "15672"

  """

  @behaviour Devcontainers.Services.Service

  alias Devcontainers.Services.ConnectionDetails

  @impl true
  def match?(image) do
    String.match?(image, ~r/^rabbitmq(:\S+)?$/)
  end

  @impl true
  def connection_details(service, container_info) do
    env = service.environment

    username = Map.get(env, "RABBITMQ_DEFAULT_USER", "guest")
    password = Map.get(env, "RABBITMQ_DEFAULT_PASS", "guest")
    vhost = Map.get(env, "RABBITMQ_DEFAULT_VHOST")

    %ConnectionDetails{
      type: :rabbitmq,
      host: container_info.host,
      port: Map.get(container_info.ports, 5672, container_info.port),
      username: username,
      password: password,
      database: vhost,
      options: %{
        management_port: Map.get(container_info.ports, 15672)
      }
    }
  end

  @impl true
  def health_check_port(_service), do: 5672

  @impl true
  def service_type, do: :rabbitmq
end
