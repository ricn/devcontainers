defmodule Devcontainers do
  @moduledoc """
  Spring Boot-style Docker Compose integration for Elixir applications.

  Devcontainers automatically manages Docker Compose services for your development
  and test environments. It discovers your `compose.yml`, starts containers when
  your application starts, extracts connection details, and stops containers on
  shutdown.

  ## Quick Start

  1. Add the dependency:

      ```elixir
      # mix.exs
      {:devcontainers, "~> 0.1.0", only: [:dev, :test]}
      ```

  2. Create a `compose.yml` in your project root:

      ```yaml
      services:
        db:
          image: postgres:15
          environment:
            POSTGRES_USER: postgres
            POSTGRES_PASSWORD: postgres
            POSTGRES_DB: myapp_dev
          ports:
            - "5432"
      ```

  3. Configure your application to use `DATABASE_URL`:

      ```elixir
      # config/runtime.exs
      if config_env() in [:dev, :test] do
        if url = System.get_env("DATABASE_URL") do
          config :my_app, MyApp.Repo, url: url
        end
      end
      ```

  4. Start your application - services start automatically!

  ## Configuration

  Configure in `config/dev.exs`:

      config :devcontainers,
        enabled: true,
        compose_file: "compose.yml",
        lifecycle: :start_and_stop,
        readiness_timeout: 60_000

  See `Devcontainers.Config` for all options.

  ## Supported Services

  - PostgreSQL (`postgres:*`)
  - MySQL/MariaDB (`mysql:*`, `mariadb:*`)
  - Redis (`redis:*`)
  - RabbitMQ (`rabbitmq:*`)
  - Kafka (`bitnami/kafka:*`, `confluentinc/cp-kafka:*`)
  - MongoDB (`mongo:*`)
  - Elasticsearch (`elasticsearch:*`)

  See `Devcontainers.Services.Registry` for registering custom handlers.
  """

  alias Devcontainers.Config
  alias Devcontainers.Lifecycle.Manager
  alias Devcontainers.Services.{Registry, ConnectionDetails}

  @doc """
  Returns whether Devcontainers is enabled.

  Checks application configuration and environment variables.

  ## Examples

      iex> Devcontainers.enabled?()
      true

  """
  @spec enabled?() :: boolean()
  defdelegate enabled?, to: Config

  @doc """
  Manually starts Docker Compose services.

  Usually not needed as services start automatically, but useful for
  manual control when `lifecycle: :none` is configured.

  ## Options

  - `:file` - Override compose file path
  - `:project_name` - Override project name
  - `:profiles` - Override profiles

  ## Examples

      # Start services from auto-detected compose file
      Devcontainers.start_services()
      # => :ok

      # Start services from specific file
      Devcontainers.start_services(file: "docker-compose.test.yml")
      # => :ok

  """
  @spec start_services(keyword()) :: :ok | {:error, term()}
  defdelegate start_services(opts \\ []), to: Manager

  @doc """
  Stops Docker Compose services.

  ## Examples

      # Stop services
      Devcontainers.stop_services()
      # => :ok

  """
  @spec stop_services() :: :ok | {:error, term()}
  defdelegate stop_services, to: Manager

  @doc """
  Returns the current status of services.

  ## Examples

      # Get current status
      Devcontainers.status()
      # => %{started: true, services: %{"db" => %ConnectionDetails{...}}}

  """
  @spec status() :: map()
  defdelegate status, to: Manager

  @doc """
  Returns connection details for a specific service.

  ## Examples

      # Get connection details for a service
      Devcontainers.connection_details("db")
      # => {:ok, %ConnectionDetails{type: :postgres, host: "localhost", port: 5432, ...}}

      Devcontainers.connection_details("nonexistent")
      # => {:error, :not_found}

  """
  @spec connection_details(String.t()) :: {:ok, ConnectionDetails.t()} | {:error, :not_found}
  defdelegate connection_details(service_name), to: Manager

  @doc """
  Returns all connection details keyed by service name.

  ## Examples

      # Get all services
      Devcontainers.all_connection_details()
      # => %{"db" => %ConnectionDetails{...}, "redis" => %ConnectionDetails{...}}

  """
  @spec all_connection_details() :: %{String.t() => ConnectionDetails.t()}
  defdelegate all_connection_details, to: Manager

  @doc """
  Returns the database URL for a service.

  Convenience function that returns the URL string directly.

  ## Examples

      # Get database URL
      Devcontainers.database_url("db")
      # => {:ok, "postgres://postgres:postgres@localhost:5432/myapp_dev"}

  """
  @spec database_url(String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def database_url(service_name) do
    case connection_details(service_name) do
      {:ok, details} -> {:ok, ConnectionDetails.to_url(details)}
      error -> error
    end
  end

  @doc """
  Returns the database URL, raising if not found.

  ## Examples

      # Get database URL, raise if not found
      Devcontainers.database_url!("db")
      # => "postgres://postgres:postgres@localhost:5432/myapp_dev"

  """
  @spec database_url!(String.t()) :: String.t()
  def database_url!(service_name) do
    case database_url(service_name) do
      {:ok, url} -> url
      {:error, :not_found} -> raise "Service #{service_name} not found"
    end
  end

  @doc """
  Registers a custom service handler.

  The handler must implement the `Devcontainers.Services.Service` behaviour.

  ## Examples

      # Register a custom handler
      Devcontainers.register_service(MyApp.Services.CustomDB)
      # => :ok

  """
  @spec register_service(module()) :: :ok
  defdelegate register_service(handler), to: Registry, as: :register

  @doc """
  Returns the list of registered service handlers.

  ## Examples

      # List registered handlers
      Devcontainers.registered_services()
      # => [Devcontainers.Services.Postgres, Devcontainers.Services.MySQL, ...]

  """
  @spec registered_services() :: [module()]
  defdelegate registered_services, to: Registry, as: :list_handlers
end
