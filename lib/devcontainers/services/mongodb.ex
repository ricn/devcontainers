defmodule Devcontainers.Services.MongoDB do
  @moduledoc """
  Service handler for MongoDB containers.

  Matches images: `mongo:*`

  ## Environment Variables

  Reads the following environment variables from the compose service:

  - `MONGO_INITDB_ROOT_USERNAME` - Root username (optional)
  - `MONGO_INITDB_ROOT_PASSWORD` - Root password (optional)
  - `MONGO_INITDB_DATABASE` - Initial database name (default: `"test"`)

  ## Example compose.yml

      services:
        mongo:
          image: mongo:7
          environment:
            MONGO_INITDB_ROOT_USERNAME: admin
            MONGO_INITDB_ROOT_PASSWORD: secret
            MONGO_INITDB_DATABASE: myapp_dev
          ports:
            - "27017"

  """

  @behaviour Devcontainers.Services.Service

  alias Devcontainers.Services.ConnectionDetails

  @impl true
  def match?(image) do
    String.match?(image, ~r/^mongo(:\S+)?$/)
  end

  @impl true
  def connection_details(service, container_info) do
    env = service.environment

    username = Map.get(env, "MONGO_INITDB_ROOT_USERNAME")
    password = Map.get(env, "MONGO_INITDB_ROOT_PASSWORD")
    database = Map.get(env, "MONGO_INITDB_DATABASE", "test")

    %ConnectionDetails{
      type: :mongodb,
      host: container_info.host,
      port: Map.get(container_info.ports, 27017, container_info.port),
      username: username,
      password: password,
      database: database
    }
  end

  @impl true
  def health_check_port(_service), do: 27017

  @impl true
  def service_type, do: :mongodb
end
