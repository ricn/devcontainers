# Phoenix Integration

This guide covers best practices for integrating Devcontainers with Phoenix applications.

## Basic Setup

### 1. Add Dependencies

```elixir
# mix.exs
defp deps do
  [
    {:phoenix, "~> 1.7"},
    {:phoenix_ecto, "~> 4.4"},
    {:ecto_sql, "~> 3.10"},
    {:postgrex, ">= 0.0.0"},
    # Add devcontainers for dev/test only
    {:devcontainers, "~> 0.1.0", only: [:dev, :test]}
  ]
end
```

### 2. Create compose.yml

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
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:
```

### 3. Configure runtime.exs

The key is configuring your Repo to use `DATABASE_URL` in `runtime.exs`:

```elixir
# config/runtime.exs
import Config

if config_env() in [:dev, :test] do
  # Devcontainers automatically sets DATABASE_URL
  if url = System.get_env("DATABASE_URL") do
    config :my_app, MyApp.Repo,
      url: url,
      pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")
  end
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise "DATABASE_URL environment variable is not set"

  config :my_app, MyApp.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")
end
```

### 4. Update dev.exs

Remove hardcoded database configuration:

```elixir
# config/dev.exs

# REMOVE this block - Devcontainers handles it:
# config :my_app, MyApp.Repo,
#   username: "postgres",
#   password: "postgres",
#   hostname: "localhost",
#   database: "myapp_dev",
#   ...

# Keep other dev settings
config :my_app, MyAppWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  # ...
```

## Running the Application

```bash
# Start Phoenix - containers start automatically
mix phx.server

# Or with IEx
iex -S mix phx.server
```

Output:
```
[info] Devcontainers: Starting services from compose.yml...
[info] Devcontainers: Services started successfully
[info] Running MyAppWeb.Endpoint with cowboy 2.10.0 at 127.0.0.1:4000 (http)
```

## Database Setup

After containers are running:

```bash
# Create and migrate database
mix ecto.setup

# Or individually
mix ecto.create
mix ecto.migrate
```

## Test Configuration

### Using Devcontainers in Tests

For integration tests that need a real database:

```elixir
# config/test.exs
config :my_app, MyApp.Repo,
  pool: Ecto.Adapters.SQL.Sandbox

# Don't set database URL here - let runtime.exs handle it
```

Run tests:

```bash
mix test
```

The database container starts automatically before tests run.

### Skipping Devcontainers for Unit Tests

If you have unit tests that mock the database:

```elixir
# config/test.exs
config :devcontainers, skip_in_tests: true
```

Or skip for specific test runs:

```bash
DEVCONTAINERS_SKIP=true mix test test/unit/
```

### Separate Test Database

Use a different compose file for tests:

```yaml
# compose.test.yml
services:
  db:
    image: postgres:15
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: myapp_test
    ports:
      - "5432"
    tmpfs:
      - /var/lib/postgresql/data  # Use tmpfs for faster tests
```

```elixir
# config/test.exs
config :devcontainers,
  compose_file: "compose.test.yml",
  project_name: "myapp_test"
```

## Multiple Databases

For apps with multiple repos:

```yaml
# compose.yml
services:
  primary_db:
    image: postgres:15
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: myapp_primary
    ports:
      - "5432"

  analytics_db:
    image: postgres:15
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: myapp_analytics
    ports:
      - "5432"
```

```elixir
# config/runtime.exs
if config_env() in [:dev, :test] do
  if url = System.get_env("DATABASE_URL") do
    config :my_app, MyApp.Repo, url: url
  end

  if url = System.get_env("ANALYTICS_DB_URL") do
    config :my_app, MyApp.AnalyticsRepo, url: url
  end
end
```

Access connection details programmatically:

```elixir
# Access specific service
{:ok, primary_url} = Devcontainers.database_url("primary_db")
{:ok, analytics_url} = Devcontainers.database_url("analytics_db")
```

## Adding Redis

Many Phoenix apps use Redis for caching or PubSub:

```yaml
# compose.yml
services:
  db:
    image: postgres:15
    # ... postgres config

  redis:
    image: redis:7-alpine
    ports:
      - "6379"
```

```elixir
# config/runtime.exs
if config_env() in [:dev, :test] do
  if redis_url = System.get_env("REDIS_URL") do
    # For Phoenix PubSub with Redis
    config :my_app, MyAppWeb.Endpoint,
      pubsub_server: MyApp.PubSub,
      pubsub: [
        name: MyApp.PubSub,
        adapter: Phoenix.PubSub.Redis,
        url: redis_url
      ]

    # For Cachex or other Redis-backed cache
    config :my_app, :redis_url, redis_url
  end
end
```

## LiveView and PubSub

With Redis for distributed PubSub:

```elixir
# lib/my_app/application.ex
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      MyApp.Repo,
      {Phoenix.PubSub, name: MyApp.PubSub, adapter: pubsub_adapter()},
      MyAppWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  defp pubsub_adapter do
    if redis_url = System.get_env("REDIS_URL") do
      {Phoenix.PubSub.Redis, url: redis_url}
    else
      Phoenix.PubSub.PG2
    end
  end
end
```

## Oban with PostgreSQL

Oban uses its own Repo, but typically shares the database:

```elixir
# config/runtime.exs
if config_env() in [:dev, :test] do
  if url = System.get_env("DATABASE_URL") do
    config :my_app, MyApp.Repo, url: url

    config :my_app, Oban,
      repo: MyApp.Repo,
      queues: [default: 10, mailers: 5]
  end
end
```

## Troubleshooting

### "relation does not exist" errors

The database exists but tables don't - run migrations:

```bash
mix ecto.migrate
```

### Ecto can't connect

1. Check containers are running: `mix devcontainers.status`
2. Check DATABASE_URL is set: `System.get_env("DATABASE_URL")` in IEx
3. Check compose file has correct ports mapping

### Slow startup in tests

Use tmpfs for faster test databases:

```yaml
# compose.test.yml
services:
  db:
    image: postgres:15
    tmpfs:
      - /var/lib/postgresql/data
```

### Port conflicts with existing PostgreSQL

Use dynamic port mapping (no host port specified):

```yaml
ports:
  - "5432"  # Let Docker assign available port
```

Devcontainers handles the port discovery automatically.

## CI/CD Integration

In CI environments, you typically start containers separately:

```yaml
# .github/workflows/test.yml
jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
        ports:
          - 5432:5432

    env:
      DATABASE_URL: postgres://postgres:postgres@localhost:5432/myapp_test
      DEVCONTAINERS_SKIP: true  # Skip Devcontainers in CI

    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
      - run: mix deps.get
      - run: mix test
```
