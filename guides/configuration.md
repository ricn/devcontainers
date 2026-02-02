# Configuration

This guide covers all configuration options for Devcontainers.

## Application Configuration

Configure Devcontainers in your `config/dev.exs` or `config/config.exs`:

```elixir
config :devcontainers,
  enabled: true,
  compose_file: "compose.yml",
  lifecycle: :start_and_stop,
  readiness_timeout: 60_000,
  skip_in_tests: false,
  profiles: [],
  project_name: nil
```

### Options

#### `enabled`

Enable or disable Devcontainers entirely.

- Type: `boolean`
- Default: `true` in `:dev` and `:test`, `false` otherwise

```elixir
config :devcontainers, enabled: false
```

#### `compose_file`

Path to the Docker Compose file.

- Type: `string` or `nil`
- Default: Auto-detects `compose.yml`, `compose.yaml`, `docker-compose.yml`, or `docker-compose.yaml`

```elixir
config :devcontainers, compose_file: "docker/compose.dev.yml"
```

#### `lifecycle`

Controls when services are started and stopped.

- Type: `:start_and_stop` | `:start_only` | `:none`
- Default: `:start_and_stop`

| Value | Behavior |
|-------|----------|
| `:start_and_stop` | Start on app start, stop on app shutdown |
| `:start_only` | Start on app start, don't stop on shutdown |
| `:none` | Don't automatically start or stop |

```elixir
# Keep containers running after app stops
config :devcontainers, lifecycle: :start_only

# Manual control only
config :devcontainers, lifecycle: :none
```

#### `readiness_timeout`

Maximum time to wait for services to become ready.

- Type: `pos_integer` (milliseconds)
- Default: `60_000` (60 seconds)

```elixir
# Wait up to 2 minutes for slow services
config :devcontainers, readiness_timeout: 120_000
```

#### `skip_in_tests`

Skip starting services when running tests.

- Type: `boolean`
- Default: `false`

```elixir
# Don't start containers for unit tests
config :devcontainers, skip_in_tests: true
```

This is useful if you use Mox or other mocking for database access in unit tests.

#### `profiles`

Docker Compose profiles to activate.

- Type: `list(string)`
- Default: `[]`

```elixir
config :devcontainers, profiles: ["dev", "debug"]
```

Corresponds to `docker compose --profile dev --profile debug up`.

#### `project_name`

Docker Compose project name.

- Type: `string` or `nil`
- Default: `nil` (uses Docker Compose's default)

```elixir
config :devcontainers, project_name: "myapp"
```

Corresponds to `docker compose -p myapp up`.

## Environment Variables

Environment variables override application configuration:

| Variable | Description | Example |
|----------|-------------|---------|
| `DEVCONTAINERS_SKIP` | Skip entirely when set to `true` or `1` | `DEVCONTAINERS_SKIP=true mix test` |
| `DEVCONTAINERS_ENABLED` | Override `enabled` config | `DEVCONTAINERS_ENABLED=false` |
| `DEVCONTAINERS_COMPOSE_FILE` | Override compose file path | `DEVCONTAINERS_COMPOSE_FILE=docker/test.yml` |

### Precedence

Environment variables have the highest precedence:

1. Environment variables (`DEVCONTAINERS_*`)
2. Application configuration (`config :devcontainers`)
3. Defaults

### Examples

```bash
# Disable for a specific command
DEVCONTAINERS_SKIP=true mix test

# Use different compose file
DEVCONTAINERS_COMPOSE_FILE=docker-compose.ci.yml mix test

# Override enabled status
DEVCONTAINERS_ENABLED=false iex -S mix
```

## Per-Environment Configuration

### Development

```elixir
# config/dev.exs
config :devcontainers,
  enabled: true,
  lifecycle: :start_and_stop
```

### Test

```elixir
# config/test.exs
config :devcontainers,
  enabled: true,
  skip_in_tests: false,  # Set to true for unit tests
  readiness_timeout: 30_000
```

### Production

Devcontainers is typically only used in dev/test, but if you include it in prod:

```elixir
# config/prod.exs
config :devcontainers, enabled: false
```

## Runtime Configuration

Some settings can be changed at runtime:

```elixir
# Manually start services (when lifecycle: :none)
Devcontainers.start_services(file: "compose.yml", profiles: ["dev"])

# Manually stop services
Devcontainers.stop_services()
```

## Compose File Labels

Control Devcontainers behavior using labels in your compose file:

### Ignoring Services

```yaml
services:
  monitoring:
    image: grafana/grafana
    labels:
      # Devcontainers won't manage this service
      devcontainers.ignore: "true"
```

## Complete Example

```elixir
# config/dev.exs
import Config

config :devcontainers,
  enabled: true,
  compose_file: "compose.yml",
  lifecycle: :start_and_stop,
  readiness_timeout: 60_000,
  profiles: ["dev"],
  project_name: "myapp_dev"

# config/test.exs
import Config

config :devcontainers,
  enabled: true,
  compose_file: "compose.yml",
  lifecycle: :start_only,  # Keep running between test runs
  readiness_timeout: 30_000,
  profiles: ["test"],
  project_name: "myapp_test"
```

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
    profiles:
      - dev
      - test

  redis:
    image: redis:7-alpine
    ports:
      - "6379"
    profiles:
      - dev
      - test

  mailhog:
    image: mailhog/mailhog
    ports:
      - "1025"
      - "8025"
    profiles:
      - dev
    labels:
      devcontainers.ignore: "true"  # We don't need connection details for this
```
