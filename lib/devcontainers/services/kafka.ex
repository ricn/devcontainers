defmodule Devcontainers.Services.Kafka do
  @moduledoc """
  Service handler for Apache Kafka containers.

  Matches images: `bitnami/kafka:*`, `confluentinc/cp-kafka:*`, `apache/kafka:*`

  ## Environment Variables

  Reads the following environment variables from the compose service:

  ### Bitnami Kafka
  - `KAFKA_CFG_ADVERTISED_LISTENERS` - Advertised listeners
  - `KAFKA_CFG_LISTENERS` - Listeners configuration

  ### Confluent Kafka
  - `KAFKA_ADVERTISED_LISTENERS` - Advertised listeners
  - `KAFKA_LISTENERS` - Listeners configuration

  ## Ports

  - `9092` - Default Kafka broker port

  ## Example compose.yml

      services:
        kafka:
          image: bitnami/kafka:3.6
          environment:
            KAFKA_CFG_NODE_ID: 0
            KAFKA_CFG_PROCESS_ROLES: controller,broker
            KAFKA_CFG_LISTENERS: PLAINTEXT://:9092,CONTROLLER://:9093
            KAFKA_CFG_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
            KAFKA_CFG_CONTROLLER_QUORUM_VOTERS: 0@kafka:9093
            KAFKA_CFG_CONTROLLER_LISTENER_NAMES: CONTROLLER
          ports:
            - "9092"

  """

  @behaviour Devcontainers.Services.Service

  alias Devcontainers.Services.ConnectionDetails

  @impl true
  def match?(image) do
    String.match?(image, ~r/^bitnami\/kafka(:\S+)?$/) or
      String.match?(image, ~r/^confluentinc\/cp-kafka(:\S+)?$/) or
      String.match?(image, ~r/^apache\/kafka(:\S+)?$/) or
      String.match?(image, ~r/^wurstmeister\/kafka(:\S+)?$/)
  end

  @impl true
  def connection_details(service, container_info) do
    %ConnectionDetails{
      type: :kafka,
      host: container_info.host,
      port: Map.get(container_info.ports, 9092, container_info.port),
      options: extract_kafka_options(service.environment)
    }
  end

  @impl true
  def health_check_port(_service), do: 9092

  @impl true
  def service_type, do: :kafka

  defp extract_kafka_options(env) do
    %{}
    |> maybe_put(:advertised_listeners, Map.get(env, "KAFKA_CFG_ADVERTISED_LISTENERS"))
    |> maybe_put(:advertised_listeners, Map.get(env, "KAFKA_ADVERTISED_LISTENERS"))
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put_new(map, key, value)
end
