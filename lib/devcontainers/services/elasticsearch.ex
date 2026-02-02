defmodule Devcontainers.Services.Elasticsearch do
  @moduledoc """
  Service handler for Elasticsearch containers.

  Matches images: `elasticsearch:*`, `docker.elastic.co/elasticsearch/*`

  ## Environment Variables

  Reads the following environment variables from the compose service:

  - `ELASTIC_USERNAME` - Username (default: `"elastic"` if password is set)
  - `ELASTIC_PASSWORD` - Password (optional)
  - `discovery.type` - Discovery type (often `"single-node"` for dev)
  - `xpack.security.enabled` - Whether security is enabled

  ## Ports

  - `9200` - HTTP REST API port
  - `9300` - Transport port (node-to-node communication)

  ## Example compose.yml

      services:
        elasticsearch:
          image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
          environment:
            discovery.type: single-node
            ELASTIC_PASSWORD: secret
            xpack.security.enabled: "true"
          ports:
            - "9200"

  """

  @behaviour Devcontainers.Services.Service

  alias Devcontainers.Services.ConnectionDetails
  alias Devcontainers.Docker.HealthCheck

  @impl true
  def match?(image) do
    String.match?(image, ~r/^elasticsearch(:\S+)?$/) or
      String.match?(image, ~r/^docker\.elastic\.co\/elasticsearch\/elasticsearch(:\S+)?$/)
  end

  @impl true
  def connection_details(service, container_info) do
    env = service.environment

    password = Map.get(env, "ELASTIC_PASSWORD")
    username = if password, do: Map.get(env, "ELASTIC_USERNAME", "elastic"), else: nil

    security_enabled =
      Map.get(env, "xpack.security.enabled", "false") in ["true", "1", true]

    scheme = if security_enabled, do: "https", else: "http"

    %ConnectionDetails{
      type: :elasticsearch,
      host: container_info.host,
      port: Map.get(container_info.ports, 9200, container_info.port),
      username: username,
      password: password,
      options: %{
        scheme: scheme,
        transport_port: Map.get(container_info.ports, 9300)
      }
    }
  end

  @impl true
  def health_check_port(_service), do: 9200

  @impl true
  def service_type, do: :elasticsearch

  @impl true
  def ready?(host, port, opts) do
    # Elasticsearch exposes a health endpoint
    if Code.ensure_loaded?(Req) do
      HealthCheck.http_ready?(host, port, Keyword.merge(opts, path: "/_cluster/health"))
    else
      HealthCheck.tcp_ready?(host, port, opts)
    end
  end
end
