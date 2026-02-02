defmodule Devcontainers.Services.MySQL do
  @moduledoc """
  Service handler for MySQL and MariaDB containers.

  Matches images: `mysql:*`, `mariadb:*`

  ## Environment Variables

  Reads the following environment variables from the compose service:

  - `MYSQL_USER` - Username (falls back to `"root"`)
  - `MYSQL_PASSWORD` - Password (falls back to `MYSQL_ROOT_PASSWORD`)
  - `MYSQL_ROOT_PASSWORD` - Root password
  - `MYSQL_DATABASE` - Database name (default: `"mysql"`)

  ## Example compose.yml

      services:
        db:
          image: mysql:8
          environment:
            MYSQL_ROOT_PASSWORD: rootsecret
            MYSQL_USER: myapp
            MYSQL_PASSWORD: secret
            MYSQL_DATABASE: myapp_dev
          ports:
            - "3306"

  """

  @behaviour Devcontainers.Services.Service

  alias Devcontainers.Services.ConnectionDetails

  @impl true
  def match?(image) do
    String.match?(image, ~r/^mysql(:\S+)?$/) or
      String.match?(image, ~r/^mariadb(:\S+)?$/)
  end

  @impl true
  def connection_details(service, container_info) do
    env = service.environment

    # MySQL allows MYSQL_USER or root with MYSQL_ROOT_PASSWORD
    username = Map.get(env, "MYSQL_USER") || "root"

    password =
      Map.get(env, "MYSQL_PASSWORD") ||
        Map.get(env, "MYSQL_ROOT_PASSWORD", "")

    database = Map.get(env, "MYSQL_DATABASE", "mysql")

    type = if String.contains?(service.image || "", "mariadb"), do: :mariadb, else: :mysql

    %ConnectionDetails{
      type: type,
      host: container_info.host,
      port: Map.get(container_info.ports, 3306, container_info.port),
      username: username,
      password: password,
      database: database
    }
  end

  @impl true
  def health_check_port(_service), do: 3306

  @impl true
  def service_type, do: :mysql
end
