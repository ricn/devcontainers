defmodule Devcontainers.Services.PostgresTest do
  use ExUnit.Case, async: true

  alias Devcontainers.Services.Postgres

  describe "match?/1" do
    test "matches postgres image" do
      assert Postgres.match?("postgres")
      assert Postgres.match?("postgres:15")
      assert Postgres.match?("postgres:15-alpine")
      assert Postgres.match?("postgres:latest")
    end

    test "matches postgis image" do
      assert Postgres.match?("postgis/postgis")
      assert Postgres.match?("postgis/postgis:15-3.4")
    end

    test "matches timescaledb image" do
      assert Postgres.match?("timescale/timescaledb")
      assert Postgres.match?("timescale/timescaledb:2.13.0-pg15")
    end

    test "does not match other images" do
      refute Postgres.match?("mysql:8")
      refute Postgres.match?("redis:7")
      refute Postgres.match?("mypostgres:latest")
    end
  end

  describe "connection_details/2" do
    test "extracts default credentials" do
      service = %{
        name: "db",
        image: "postgres:15",
        environment: %{},
        ports: [],
        labels: %{},
        depends_on: [],
        profiles: []
      }

      container_info = %{host: "localhost", port: 5432, ports: %{5432 => 5432}}
      details = Postgres.connection_details(service, container_info)

      assert details.type == :postgres
      assert details.host == "localhost"
      assert details.port == 5432
      assert details.username == "postgres"
      assert details.password == "postgres"
      assert details.database == "postgres"
    end

    test "extracts custom credentials from environment" do
      service = %{
        name: "db",
        image: "postgres:15",
        environment: %{
          "POSTGRES_USER" => "myuser",
          "POSTGRES_PASSWORD" => "mysecret",
          "POSTGRES_DB" => "mydb"
        },
        ports: [],
        labels: %{},
        depends_on: [],
        profiles: []
      }

      container_info = %{host: "localhost", port: 32768, ports: %{5432 => 32768}}
      details = Postgres.connection_details(service, container_info)

      assert details.username == "myuser"
      assert details.password == "mysecret"
      assert details.database == "mydb"
      assert details.port == 32768
    end

    test "defaults database to username when not specified" do
      service = %{
        name: "db",
        image: "postgres:15",
        environment: %{
          "POSTGRES_USER" => "myuser",
          "POSTGRES_PASSWORD" => "mysecret"
        },
        ports: [],
        labels: %{},
        depends_on: [],
        profiles: []
      }

      container_info = %{host: "localhost", port: 5432, ports: %{5432 => 5432}}
      details = Postgres.connection_details(service, container_info)

      assert details.database == "myuser"
    end
  end

  describe "health_check_port/1" do
    test "returns 5432" do
      assert Postgres.health_check_port(%{}) == 5432
    end
  end

  describe "service_type/0" do
    test "returns :postgres" do
      assert Postgres.service_type() == :postgres
    end
  end
end
