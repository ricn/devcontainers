# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2024-XX-XX

### Added

- Initial release
- Auto-discovery of `compose.yml` and `docker-compose.yml` files
- Automatic starting of Docker Compose services on application start
- Automatic stopping of services on application shutdown
- Service connection extraction for:
  - PostgreSQL (`postgres:*`, `postgis/postgis:*`, `timescale/timescaledb:*`)
  - MySQL/MariaDB (`mysql:*`, `mariadb:*`)
  - Redis (`redis:*`, `bitnami/redis:*`)
  - RabbitMQ (`rabbitmq:*`)
  - Kafka (`bitnami/kafka:*`, `confluentinc/cp-kafka:*`)
  - MongoDB (`mongo:*`)
  - Elasticsearch (`elasticsearch:*`, `docker.elastic.co/elasticsearch/*`)
- Environment variable injection (`DATABASE_URL`, etc.)
- Custom service handler support via `Service` behaviour
- Mix tasks:
  - `mix devcontainers.init` - Generate compose.yml
  - `mix devcontainers.up` - Start services
  - `mix devcontainers.down` - Stop services
  - `mix devcontainers.status` - Show service status
- Configuration options:
  - `enabled` - Enable/disable the package
  - `compose_file` - Custom compose file path
  - `lifecycle` - Control start/stop behavior
  - `readiness_timeout` - Timeout for health checks
  - `skip_in_tests` - Skip in test environment
  - `profiles` - Docker Compose profiles
  - `project_name` - Docker Compose project name
- Environment variable overrides:
  - `DEVCONTAINERS_SKIP`
  - `DEVCONTAINERS_ENABLED`
  - `DEVCONTAINERS_COMPOSE_FILE`
- Support for ignore labels:
  - `devcontainers.ignore`
