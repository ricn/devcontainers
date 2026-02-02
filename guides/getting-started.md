# Getting Started

This guide will walk you through setting up Devcontainers in your Elixir/Phoenix project.

## Prerequisites

- Docker Desktop or Docker Engine with Docker Compose
- Elixir 1.14 or later

Verify Docker is available:

```bash
docker compose version
```

## Installation

Add `devcontainers` to your dependencies in `mix.exs`:

```elixir
defp deps do
  [
    # ... other deps
    {:devcontainers, "~> 0.1.0", only: [:dev, :test]}
  ]
end
```

Then fetch dependencies:

```bash
mix deps.get
```

## Creating a Compose File

### Option 1: Use the generator

The easiest way to get started is with the generator:

```bash
# Create with PostgreSQL
mix devcontainers.init --postgres

# Create with multiple services
mix devcontainers.init --postgres --redis

# See all options
mix help devcontainers.init
```

### Option 2: Create manually

Create a `compose.yml` in your project root:

```yaml
services:
  db:
    image: postgres:15
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: myapp_dev
    ports:
      - "5432"  # Let Docker assign a random host port
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

**Important**: Use dynamic port mapping (just `"5432"` not `"5432:5432"`) to avoid port conflicts.

## Configuring Your Application

### For Phoenix with Ecto

Update `config/runtime.exs` to use `DATABASE_URL`:

```elixir
import Config

if config_env() in [:dev, :test] do
  # Devcontainers sets DATABASE_URL automatically
  if url = System.get_env("DATABASE_URL") do
    config :my_app, MyApp.Repo,
      url: url,
      pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")
  end
end

if config_env() == :prod do
  # Production config...
end
```

Remove hardcoded database config from `config/dev.exs`:

```elixir
# config/dev.exs
# Remove or comment out:
# config :my_app, MyApp.Repo,
#   username: "postgres",
#   password: "postgres",
#   ...
```

### For non-Phoenix applications

Access connection details programmatically:

```elixir
# In your application startup
{:ok, details} = Devcontainers.connection_details("db")
# Use details.host, details.port, details.username, etc.
```

## Running Your Application

Start your application normally:

```bash
# Phoenix
iex -S mix phx.server

# Regular Elixir
iex -S mix
```

You should see logs indicating services are starting:

```
[info] Devcontainers: Starting services from compose.yml...
[info] Devcontainers: Services started successfully
[debug] Set DATABASE_URL=postgres://postgres:postgres@localhost:32768/myapp_dev
```

## Verifying It Works

### Check service status

```bash
mix devcontainers.status
```

Output:
```
Services from compose.yml:

  db (myapp-db-1)
    State: running - Up 5 seconds (healthy)
    Ports: 32768->5432
```

### In IEx

```elixir
iex> Devcontainers.status()
%{
  started: true,
  services: %{
    "db" => %Devcontainers.Services.ConnectionDetails{
      type: :postgres,
      host: "localhost",
      port: 32768,
      username: "postgres",
      password: "postgres",
      database: "myapp_dev"
    }
  }
}

iex> System.get_env("DATABASE_URL")
"postgres://postgres:postgres@localhost:32768/myapp_dev"
```

## What Happens on Shutdown

When you stop your application (Ctrl+C twice), Devcontainers automatically stops the Docker containers:

```
[info] Devcontainers: Stopping services...
```

Your data is preserved in Docker volumes and will be available when you restart.

## Next Steps

- [Configuration Guide](configuration.md) - All configuration options
- [Phoenix Integration](phoenix-integration.md) - Detailed Phoenix setup
- [Custom Services](custom-services.md) - Support for custom Docker images

## Troubleshooting

### Services don't start

1. Check Docker is running: `docker info`
2. Check compose file syntax: `docker compose -f compose.yml config`
3. Check Devcontainers is enabled: `Devcontainers.enabled?()` in IEx

### Port conflicts

Use dynamic port mapping in your compose file:

```yaml
ports:
  - "5432"  # Good - Docker assigns available port
  # NOT:
  # - "5432:5432"  # May conflict with existing services
```

### Slow startup

Increase the readiness timeout:

```elixir
# config/dev.exs
config :devcontainers,
  readiness_timeout: 120_000  # 2 minutes
```
