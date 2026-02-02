defmodule Devcontainers.Services.RedisTest do
  use ExUnit.Case, async: true

  alias Devcontainers.Services.Redis

  describe "match?/1" do
    test "matches redis image" do
      assert Redis.match?("redis")
      assert Redis.match?("redis:7")
      assert Redis.match?("redis:7-alpine")
      assert Redis.match?("redis:latest")
    end

    test "matches bitnami redis image" do
      assert Redis.match?("bitnami/redis")
      assert Redis.match?("bitnami/redis:7.2")
    end

    test "does not match other images" do
      refute Redis.match?("postgres:15")
      refute Redis.match?("mysql:8")
      refute Redis.match?("myredis:latest")
    end
  end

  describe "connection_details/2" do
    test "extracts basic connection details" do
      service = %{
        name: "redis",
        image: "redis:7",
        environment: %{},
        ports: [],
        labels: %{},
        depends_on: [],
        profiles: []
      }

      container_info = %{host: "localhost", port: 6379, ports: %{6379 => 6379}}
      details = Redis.connection_details(service, container_info)

      assert details.type == :redis
      assert details.host == "localhost"
      assert details.port == 6379
      assert details.password == nil
    end

    test "extracts password from environment" do
      service = %{
        name: "redis",
        image: "redis:7",
        environment: %{
          "REDIS_PASSWORD" => "mysecret"
        },
        ports: [],
        labels: %{},
        depends_on: [],
        profiles: []
      }

      container_info = %{host: "localhost", port: 6379, ports: %{6379 => 6379}}
      details = Redis.connection_details(service, container_info)

      assert details.password == "mysecret"
    end
  end

  describe "health_check_port/1" do
    test "returns 6379" do
      assert Redis.health_check_port(%{}) == 6379
    end
  end
end
