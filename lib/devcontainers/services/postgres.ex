defmodule Devcontainers.Services.Postgres do
  @moduledoc """
  Service handler for PostgreSQL containers.

  Matches images: `postgres:*`, `postgis/postgis:*`, `timescale/timescaledb:*`

  ## Environment Variables

  Reads the following environment variables from the compose service:

  - `POSTGRES_USER` - Username (default: `"postgres"`)
  - `POSTGRES_PASSWORD` - Password (default: `"postgres"`)
  - `POSTGRES_DB` - Database name (default: value of `POSTGRES_USER`)

  ## Example compose.yml

      services:
        db:
          image: postgres:15
          environment:
            POSTGRES_USER: myapp
            POSTGRES_PASSWORD: secret
            POSTGRES_DB: myapp_dev
          ports:
            - "5432"

  """

  @behaviour Devcontainers.Services.Service

  alias Devcontainers.Services.ConnectionDetails

  @impl true
  def match?(image) do
    String.match?(image, ~r/^postgres(:\S+)?$/) or
      String.match?(image, ~r/^postgis\/postgis(:\S+)?$/) or
      String.match?(image, ~r/^timescale\/timescaledb(:\S+)?$/)
  end

  @impl true
  def connection_details(service, container_info) do
    env = service.environment

    username = Map.get(env, "POSTGRES_USER", "postgres")
    password = Map.get(env, "POSTGRES_PASSWORD", "postgres")
    database = Map.get(env, "POSTGRES_DB", username)

    %ConnectionDetails{
      type: :postgres,
      host: container_info.host,
      port: Map.get(container_info.ports, 5432, container_info.port),
      username: username,
      password: password,
      database: database
    }
  end

  @impl true
  def health_check_port(_service), do: 5432

  @impl true
  def service_type, do: :postgres
end
