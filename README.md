# Devcontainers

[![Hex.pm](https://img.shields.io/hexpm/v/devcontainers.svg)](https://hex.pm/packages/devcontainers)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/devcontainers)
[![CI](https://github.com/yourusername/devcontainers/actions/workflows/ci.yml/badge.svg)](https://github.com/yourusername/devcontainers/actions)

Spring Boot-style Docker Compose integration for Elixir applications.

Devcontainers automatically manages Docker Compose services for your development and test environments:

- 🔍 **Auto-discovers** `compose.yml` in your project
- 🚀 **Auto-starts** containers when your app starts
- 🔗 **Auto-configures** connection details (sets `DATABASE_URL`, etc.)
- 🛑 **Auto-stops** containers when your app shuts down

Inspired by [Spring Boot's Docker Compose support](https://docs.spring.io/spring-boot/docs/current/reference/html/features.html#features.docker-compose).

## Quick Start

### 1. Add the dependency

```elixir
# mix.exs
defp deps do
  [
    {:devcontainers, "~> 0.1.0", only: [:dev, :test]}
  ]
end
```

### 2. Create a compose.yml

```yaml
# compose.yml
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

Or generate one:

```bash
mix devcontainers.init --postgres
```

### 3. Configure your app to use DATABASE_URL

```elixir
# config/runtime.exs
if config_env() in [:dev, :test] do
  if url = System.get_env("DATABASE_URL") do
    config :my_app, MyApp.Repo, url: url
  end
end
```

### 4. Start your app

```bash
iex -S mix phx.server
```

That's it! PostgreSQL starts automatically and `DATABASE_URL` is set.

## Supported Services

| Service | Images | Environment Variables |
|---------|--------|----------------------|
| PostgreSQL | `postgres:*`, `postgis/postgis:*`, `timescale/timescaledb:*` | `DATABASE_URL`, `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` |
| MySQL/MariaDB | `mysql:*`, `mariadb:*` | `DATABASE_URL`, `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` |
| Redis | `redis:*`, `bitnami/redis:*` | `REDIS_URL`, `REDIS_HOST`, `REDIS_PORT` |
| RabbitMQ | `rabbitmq:*` | `RABBITMQ_URL`, `RABBITMQ_HOST`, `RABBITMQ_PORT` |
| Kafka | `bitnami/kafka:*`, `confluentinc/cp-kafka:*` | `KAFKA_BOOTSTRAP_SERVERS`, `KAFKA_HOST`, `KAFKA_PORT` |
| MongoDB | `mongo:*` | `MONGODB_URL`, `MONGO_HOST`, `MONGO_PORT` |
| Elasticsearch | `elasticsearch:*`, `docker.elastic.co/elasticsearch/*` | `ELASTICSEARCH_URL`, `ELASTICSEARCH_HOST`, `ELASTICSEARCH_PORT` |

## Configuration

Configure in `config/dev.exs`:

```elixir
config :devcontainers,
  enabled: true,                    # Enable/disable (default: true in dev/test)
  compose_file: "compose.yml",      # Path to compose file (default: auto-detect)
  lifecycle: :start_and_stop,       # :start_and_stop | :start_only | :none
  readiness_timeout: 60_000,        # Timeout waiting for services (ms)
  skip_in_tests: false,             # Skip in test environment
  profiles: [],                     # Docker Compose profiles to activate
  project_name: nil                 # Docker Compose project name
```

### Environment Variables

Override configuration with environment variables:

```bash
DEVCONTAINERS_SKIP=true        # Skip entirely
DEVCONTAINERS_ENABLED=false    # Disable
DEVCONTAINERS_COMPOSE_FILE=... # Override compose file path
```

## Mix Tasks

```bash
# Generate a compose.yml
mix devcontainers.init --postgres --redis

# Start services manually
mix devcontainers.up

# Stop services
mix devcontainers.down

# Show service status
mix devcontainers.status
```

## Programmatic Access

```elixir
# Get connection details
{:ok, details} = Devcontainers.connection_details("db")
# => %ConnectionDetails{type: :postgres, host: "localhost", port: 5432, ...}

# Get database URL directly
{:ok, url} = Devcontainers.database_url("db")
# => "postgres://postgres:postgres@localhost:5432/myapp_dev"

# Check status
Devcontainers.status()
# => %{started: true, services: %{"db" => %ConnectionDetails{...}}}
```

## Custom Service Handlers

Support custom Docker images by implementing the `Devcontainers.Services.Service` behaviour:

```elixir
defmodule MyApp.Services.CustomDB do
  @behaviour Devcontainers.Services.Service

  @impl true
  def match?(image), do: String.starts_with?(image, "mycompany/customdb")

  @impl true
  def connection_details(service, container_info) do
    %Devcontainers.Services.ConnectionDetails{
      type: :customdb,
      host: container_info.host,
      port: Map.get(container_info.ports, 9000, container_info.port),
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

# Register at application startup
Devcontainers.register_service(MyApp.Services.CustomDB)
```

## Ignoring Services

Skip specific services using labels:

```yaml
services:
  monitoring:
    image: grafana/grafana
    labels:
      devcontainers.ignore: "true"  # Devcontainers will ignore this
```

Also supports Spring Boot's label for compatibility:
- `org.springframework.boot.ignore: "true"`

## How It Works

1. **Discovery**: On application start, Devcontainers looks for `compose.yml` or `docker-compose.yml`
2. **Start**: Runs `docker compose up -d --wait`
3. **Health Check**: Waits for each service to accept TCP connections
4. **Connection Details**: Parses compose file, matches services to handlers, extracts credentials
5. **Environment**: Sets `DATABASE_URL` and service-specific environment variables
6. **Shutdown**: On application stop, runs `docker compose stop`

## Phoenix Integration

Devcontainers works seamlessly with Phoenix. The key is using `runtime.exs`:

```elixir
# config/runtime.exs
import Config

if config_env() in [:dev, :test] do
  # Devcontainers sets DATABASE_URL automatically
  if url = System.get_env("DATABASE_URL") do
    config :my_app, MyApp.Repo,
      url: url,
      pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")
  end

  # Same for Redis if you use it
  if redis_url = System.get_env("REDIS_URL") do
    config :my_app, :redis_url, redis_url
  end
end
```

## Comparison with Spring Boot

| Feature | Spring Boot | Devcontainers |
|---------|-------------|---------------|
| Auto-discovery | ✅ | ✅ |
| Auto-start | ✅ | ✅ |
| Service connections | ✅ Bean-based | ✅ Environment variables |
| Auto-stop | ✅ | ✅ |
| Custom handlers | Via `DockerComposeConnectionDetailsFactory` | Via `Service` behaviour |
| Ignore labels | `org.springframework.boot.ignore` | Both `devcontainers.ignore` and Spring's label |

## Requirements

- Docker with Docker Compose (v2 preferred, v1 supported)
- Elixir 1.14+

## License

MIT License - see [LICENSE](LICENSE) for details.