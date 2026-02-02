# Custom Services

This guide explains how to add support for custom Docker images that Devcontainers doesn't support out of the box.

## When You Need Custom Handlers

You need a custom handler when:

- Using an internal/private Docker image
- Using an image not supported by default
- Needing custom credential extraction logic
- Wanting to override default behavior for a supported image

## Creating a Custom Handler

Implement the `Devcontainers.Services.Service` behaviour:

```elixir
defmodule MyApp.Services.CustomDB do
  @behaviour Devcontainers.Services.Service

  alias Devcontainers.Services.ConnectionDetails

  @impl true
  def match?(image) do
    # Return true if this handler supports the image
    String.starts_with?(image, "mycompany/customdb") or
      String.starts_with?(image, "registry.internal/db")
  end

  @impl true
  def connection_details(service, container_info) do
    # Extract connection details from the service definition
    # and container runtime info
    env = service.environment

    %ConnectionDetails{
      type: :customdb,
      host: container_info.host,
      port: Map.get(container_info.ports, 9000, container_info.port),
      username: Map.get(env, "CUSTOM_USER", "admin"),
      password: Map.get(env, "CUSTOM_PASSWORD", ""),
      database: Map.get(env, "CUSTOM_DATABASE", "default"),
      options: %{
        # Any additional options
        ssl: Map.get(env, "CUSTOM_SSL", "false") == "true"
      }
    }
  end

  @impl true
  def health_check_port(_service) do
    # Return the container port to check for readiness
    9000
  end

  @impl true
  def service_type do
    # Return an atom identifying the service type
    :customdb
  end
end
```

## Callback Reference

### `match?/1` (required)

```elixir
@callback match?(image :: String.t()) :: boolean()
```

Returns `true` if this handler supports the given Docker image.

The `image` parameter is the full image reference from the compose file (e.g., `"postgres:15"`, `"mycompany/db:latest"`).

**Example patterns:**

```elixir
# Match by prefix
def match?(image), do: String.starts_with?(image, "mycompany/")

# Match by exact name (any tag)
def match?(image), do: String.match?(image, ~r/^mydb(:\S+)?$/)

# Match multiple images
def match?(image) do
  Enum.any?([
    ~r/^mydb(:\S+)?$/,
    ~r/^registry\.internal\/db(:\S+)?$/
  ], &Regex.match?(&1, image))
end
```

### `connection_details/2` (required)

```elixir
@callback connection_details(service, container_info) :: ConnectionDetails.t()
```

Extracts connection details from the service definition and container info.

**Parameters:**

- `service` - Parsed compose service definition:
  ```elixir
  %{
    name: "db",
    image: "mycompany/customdb:1.0",
    environment: %{"USER" => "admin", "PASSWORD" => "secret"},
    ports: [%{host: nil, container: 9000, protocol: "tcp"}],
    labels: %{},
    depends_on: [],
    profiles: []
  }
  ```

- `container_info` - Runtime container information:
  ```elixir
  %{
    host: "localhost",
    port: 32768,          # First mapped port
    ports: %{9000 => 32768, 9001 => 32769}  # All port mappings
  }
  ```

### `health_check_port/1` (required)

```elixir
@callback health_check_port(service) :: non_neg_integer()
```

Returns the container port to check for TCP readiness.

This is the **container** port, not the host port. Devcontainers will look up the mapped host port automatically.

### `service_type/0` (required)

```elixir
@callback service_type() :: atom()
```

Returns an atom identifying the service type. Used for URL generation and environment variable naming.

### `ready?/3` (optional)

```elixir
@callback ready?(host :: String.t(), port :: non_neg_integer(), opts :: keyword()) :: boolean()
```

Optional custom readiness check beyond TCP connectivity.

Useful for services that need protocol-level verification:

```elixir
@impl true
def ready?(host, port, _opts) do
  # TCP is connected, now verify protocol
  case connect_and_ping(host, port) do
    :pong -> true
    _ -> false
  end
end

defp connect_and_ping(host, port) do
  # Custom protocol check
end
```

## Registering Handlers

Register your handler at application startup:

```elixir
# lib/my_app/application.ex
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    # Register custom handler before Devcontainers starts
    Devcontainers.register_service(MyApp.Services.CustomDB)

    children = [
      # ... your supervision tree
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
```

**Important:** Register handlers early in your application startup, before accessing services.

### Handler Priority

Handlers are matched in registration order. Custom handlers registered via `register_service/1` are prepended to the list and take priority over built-in handlers.

This allows you to override default behavior:

```elixir
# Override the default PostgreSQL handler
defmodule MyApp.Services.CustomPostgres do
  @behaviour Devcontainers.Services.Service

  @impl true
  def match?(image), do: String.starts_with?(image, "postgres")

  # Custom implementation...
end

# Register to override default
Devcontainers.register_service(MyApp.Services.CustomPostgres)
```

## Connection Details

The `ConnectionDetails` struct:

```elixir
%Devcontainers.Services.ConnectionDetails{
  type: :customdb,      # Service type atom
  host: "localhost",    # Host address
  port: 32768,          # Mapped host port
  username: "admin",    # Optional username
  password: "secret",   # Optional password
  database: "mydb",     # Optional database/vhost name
  options: %{}          # Additional service-specific options
}
```

### URL Generation

`ConnectionDetails.to_url/1` generates URLs based on the `type`:

| Type | URL Format |
|------|------------|
| `:postgres`, `:postgresql` | `postgres://user:pass@host:port/db` |
| `:mysql`, `:mariadb` | `mysql://user:pass@host:port/db` |
| `:redis` | `redis://host:port` or `redis://:pass@host:port/db` |
| `:rabbitmq` | `amqp://user:pass@host:port/vhost` |
| `:mongodb` | `mongodb://user:pass@host:port/db` |
| `:elasticsearch` | `http://user:pass@host:port` |
| `:kafka` | `host:port` (bootstrap servers) |
| Other | `type://user:pass@host:port` |

For custom URL formats, you can override or add methods in your handler.

### Environment Variables

`ConnectionDetails.to_env_vars/2` generates environment variables:

```elixir
details = %ConnectionDetails{type: :customdb, host: "localhost", port: 9000, ...}
env = ConnectionDetails.to_env_vars(details, "myservice")

# Returns:
%{
  "MYSERVICE_HOST" => "localhost",
  "MYSERVICE_PORT" => "9000",
  "MYSERVICE_USER" => "admin",
  "MYSERVICE_PASSWORD" => "secret",
  "MYSERVICE_NAME" => "mydb",
  "MYSERVICE_URL" => "customdb://admin:secret@localhost:9000"
}
```

## Complete Example

Here's a complete example for a hypothetical ScyllaDB service:

```elixir
defmodule MyApp.Services.ScyllaDB do
  @behaviour Devcontainers.Services.Service

  alias Devcontainers.Services.ConnectionDetails

  @scylla_images [
    ~r/^scylladb\/scylla(:\S+)?$/,
    ~r/^scylla(:\S+)?$/
  ]

  @impl true
  def match?(image) do
    Enum.any?(@scylla_images, &Regex.match?(&1, image))
  end

  @impl true
  def connection_details(service, container_info) do
    env = service.environment

    %ConnectionDetails{
      type: :scylladb,
      host: container_info.host,
      port: Map.get(container_info.ports, 9042, container_info.port),
      username: Map.get(env, "SCYLLA_USER"),
      password: Map.get(env, "SCYLLA_PASSWORD"),
      database: Map.get(env, "SCYLLA_KEYSPACE", "system"),
      options: %{
        cql_port: Map.get(container_info.ports, 9042),
        thrift_port: Map.get(container_info.ports, 9160),
        shard_aware_port: Map.get(container_info.ports, 19042)
      }
    }
  end

  @impl true
  def health_check_port(_service), do: 9042

  @impl true
  def service_type, do: :scylladb

  # Optional: Custom readiness check using CQL protocol
  @impl true
  def ready?(host, port, _opts) do
    case :gen_tcp.connect(to_charlist(host), port, [:binary, active: false], 1000) do
      {:ok, socket} ->
        # Send CQL OPTIONS frame
        :gen_tcp.send(socket, <<4, 0, 0, 0, 5, 0, 0, 0, 0>>)
        result = case :gen_tcp.recv(socket, 0, 1000) do
          {:ok, <<4, 0, 0, 0, 6, _rest::binary>>} -> true  # SUPPORTED response
          _ -> false
        end
        :gen_tcp.close(socket)
        result
      _ ->
        false
    end
  rescue
    _ -> false
  end
end
```

Usage in compose.yml:

```yaml
services:
  scylla:
    image: scylladb/scylla:5.4
    environment:
      SCYLLA_KEYSPACE: myapp
    ports:
      - "9042"
      - "9160"
```
