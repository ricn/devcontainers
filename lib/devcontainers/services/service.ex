defmodule Devcontainers.Services.Service do
  @moduledoc """
  Behaviour for service handlers.

  Service handlers are responsible for detecting specific Docker images
  and extracting connection details from running containers.

  ## Implementing a Custom Handler

      defmodule MyApp.Services.CustomDB do
        @behaviour Devcontainers.Services.Service

        @impl true
        def match?(image) do
          String.starts_with?(image, "mycompany/customdb")
        end

        @impl true
        def connection_details(service, container_info) do
          %Devcontainers.Services.ConnectionDetails{
            type: :customdb,
            host: container_info.host,
            port: container_info.port,
            username: Map.get(service.environment, "DB_USER", "admin"),
            password: Map.get(service.environment, "DB_PASSWORD", "secret"),
            database: Map.get(service.environment, "DB_NAME", "default")
          }
        end

        @impl true
        def health_check_port(_service), do: 9000

        @impl true
        def service_type, do: :customdb
      end

  ## Registration

  Register your custom handler with the registry:

      Devcontainers.Services.Registry.register(MyApp.Services.CustomDB)

  """

  alias Devcontainers.Services.ConnectionDetails
  alias Devcontainers.Docker.ComposeFile

  @type container_info :: %{
          host: String.t(),
          port: non_neg_integer(),
          ports: %{non_neg_integer() => non_neg_integer()}
        }

  @doc """
  Returns true if this handler supports the given Docker image.

  The image string includes the full image reference (e.g., "postgres:15", "redis:alpine").
  """
  @callback match?(image :: String.t()) :: boolean()

  @doc """
  Extracts connection details from a service definition and container info.

  The service contains the parsed compose file service definition.
  The container_info contains runtime information like mapped ports.
  """
  @callback connection_details(
              service :: ComposeFile.service(),
              container_info :: container_info()
            ) :: ConnectionDetails.t()

  @doc """
  Returns the container port to use for health checking.
  """
  @callback health_check_port(service :: ComposeFile.service()) :: non_neg_integer()

  @doc """
  Returns the service type atom (e.g., :postgres, :redis).
  """
  @callback service_type() :: atom()

  @doc """
  Optional callback for custom readiness checks beyond TCP connectivity.

  Default implementation returns true (TCP check is sufficient).
  """
  @callback ready?(host :: String.t(), port :: non_neg_integer(), opts :: keyword()) :: boolean()

  @optional_callbacks [ready?: 3]
end
