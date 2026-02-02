defmodule Devcontainers.Docker.ComposeFileTest do
  use ExUnit.Case, async: true

  alias Devcontainers.Docker.ComposeFile

  describe "parse_string/1" do
    test "parses a simple compose file" do
      yaml = """
      services:
        db:
          image: postgres:15
          environment:
            POSTGRES_USER: postgres
            POSTGRES_PASSWORD: secret
          ports:
            - "5432"
      """

      assert {:ok, compose} = ComposeFile.parse_string(yaml)
      assert Map.has_key?(compose.services, "db")

      service = compose.services["db"]
      assert service.name == "db"
      assert service.image == "postgres:15"
      assert service.environment["POSTGRES_USER"] == "postgres"
      assert service.environment["POSTGRES_PASSWORD"] == "secret"
    end

    test "parses multiple services" do
      yaml = """
      services:
        db:
          image: postgres:15
        redis:
          image: redis:7
        kafka:
          image: bitnami/kafka:3.6
      """

      assert {:ok, compose} = ComposeFile.parse_string(yaml)
      assert Map.keys(compose.services) |> Enum.sort() == ["db", "kafka", "redis"]
    end

    test "parses environment as list" do
      yaml = """
      services:
        db:
          image: postgres:15
          environment:
            - POSTGRES_USER=admin
            - POSTGRES_PASSWORD=secret
            - EMPTY_VAR
      """

      assert {:ok, compose} = ComposeFile.parse_string(yaml)
      env = compose.services["db"].environment

      assert env["POSTGRES_USER"] == "admin"
      assert env["POSTGRES_PASSWORD"] == "secret"
      assert env["EMPTY_VAR"] == ""
    end

    test "parses environment as map" do
      yaml = """
      services:
        db:
          image: postgres:15
          environment:
            POSTGRES_USER: admin
            POSTGRES_PASSWORD: secret
      """

      assert {:ok, compose} = ComposeFile.parse_string(yaml)
      env = compose.services["db"].environment

      assert env["POSTGRES_USER"] == "admin"
      assert env["POSTGRES_PASSWORD"] == "secret"
    end

    test "parses port as integer" do
      yaml = """
      services:
        db:
          image: postgres:15
          ports:
            - 5432
      """

      assert {:ok, compose} = ComposeFile.parse_string(yaml)
      [port] = compose.services["db"].ports

      assert port.container == 5432
      assert port.host == nil
      assert port.protocol == "tcp"
    end

    test "parses port as string with host port" do
      yaml = """
      services:
        db:
          image: postgres:15
          ports:
            - "5433:5432"
      """

      assert {:ok, compose} = ComposeFile.parse_string(yaml)
      [port] = compose.services["db"].ports

      assert port.container == 5432
      assert port.host == 5433
    end

    test "parses port with protocol" do
      yaml = """
      services:
        app:
          image: myapp
          ports:
            - "8080:80/tcp"
            - "5000:5000/udp"
      """

      assert {:ok, compose} = ComposeFile.parse_string(yaml)
      ports = compose.services["app"].ports

      tcp_port = Enum.find(ports, &(&1.protocol == "tcp"))
      udp_port = Enum.find(ports, &(&1.protocol == "udp"))

      assert tcp_port.container == 80
      assert tcp_port.host == 8080

      assert udp_port.container == 5000
      assert udp_port.protocol == "udp"
    end

    test "parses port with IP binding" do
      yaml = """
      services:
        db:
          image: postgres:15
          ports:
            - "127.0.0.1:5433:5432"
      """

      assert {:ok, compose} = ComposeFile.parse_string(yaml)
      [port] = compose.services["db"].ports

      assert port.container == 5432
      assert port.host == 5433
    end

    test "parses long-form port syntax" do
      yaml = """
      services:
        db:
          image: postgres:15
          ports:
            - target: 5432
              published: 5433
              protocol: tcp
      """

      assert {:ok, compose} = ComposeFile.parse_string(yaml)
      [port] = compose.services["db"].ports

      assert port.container == 5432
      assert port.host == 5433
      assert port.protocol == "tcp"
    end

    test "parses labels as list" do
      yaml = """
      services:
        db:
          image: postgres:15
          labels:
            - devcontainers.ignore=true
            - com.example.env=dev
      """

      assert {:ok, compose} = ComposeFile.parse_string(yaml)
      labels = compose.services["db"].labels

      assert labels["devcontainers.ignore"] == "true"
      assert labels["com.example.env"] == "dev"
    end

    test "parses labels as map" do
      yaml = """
      services:
        db:
          image: postgres:15
          labels:
            devcontainers.ignore: "true"
            com.example.env: dev
      """

      assert {:ok, compose} = ComposeFile.parse_string(yaml)
      labels = compose.services["db"].labels

      assert labels["devcontainers.ignore"] == "true"
      assert labels["com.example.env"] == "dev"
    end

    test "parses depends_on as list" do
      yaml = """
      services:
        app:
          image: myapp
          depends_on:
            - db
            - redis
        db:
          image: postgres:15
        redis:
          image: redis:7
      """

      assert {:ok, compose} = ComposeFile.parse_string(yaml)
      assert compose.services["app"].depends_on == ["db", "redis"]
    end

    test "parses depends_on as map" do
      yaml = """
      services:
        app:
          image: myapp
          depends_on:
            db:
              condition: service_healthy
            redis:
              condition: service_started
        db:
          image: postgres:15
        redis:
          image: redis:7
      """

      assert {:ok, compose} = ComposeFile.parse_string(yaml)
      assert "db" in compose.services["app"].depends_on
      assert "redis" in compose.services["app"].depends_on
    end

    test "parses profiles" do
      yaml = """
      services:
        db:
          image: postgres:15
          profiles:
            - dev
            - test
      """

      assert {:ok, compose} = ComposeFile.parse_string(yaml)
      assert compose.services["db"].profiles == ["dev", "test"]
    end

    test "handles service without image" do
      yaml = """
      services:
        app:
          build: .
          ports:
            - "3000"
      """

      assert {:ok, compose} = ComposeFile.parse_string(yaml)
      assert compose.services["app"].image == nil
    end

    test "parses version field (deprecated but still used)" do
      yaml = """
      version: "3.8"
      services:
        db:
          image: postgres:15
      """

      assert {:ok, compose} = ComposeFile.parse_string(yaml)
      assert compose.version == "3.8"
    end
  end

  describe "active_services/1" do
    test "returns services without ignore labels" do
      yaml = """
      services:
        db:
          image: postgres:15
        redis:
          image: redis:7
          labels:
            devcontainers.ignore: "true"
      """

      {:ok, compose} = ComposeFile.parse_string(yaml)
      active = ComposeFile.active_services(compose)

      assert length(active) == 1
      assert hd(active).name == "db"
    end

    test "respects Spring Boot ignore label" do
      yaml = """
      services:
        db:
          image: postgres:15
        monitoring:
          image: grafana/grafana
          labels:
            org.springframework.boot.ignore: "true"
      """

      {:ok, compose} = ComposeFile.parse_string(yaml)
      active = ComposeFile.active_services(compose)

      assert length(active) == 1
      assert hd(active).name == "db"
    end
  end

  describe "get_service/2" do
    test "returns service by name" do
      yaml = """
      services:
        db:
          image: postgres:15
      """

      {:ok, compose} = ComposeFile.parse_string(yaml)
      assert {:ok, service} = ComposeFile.get_service(compose, "db")
      assert service.name == "db"
    end

    test "returns error for unknown service" do
      yaml = """
      services:
        db:
          image: postgres:15
      """

      {:ok, compose} = ComposeFile.parse_string(yaml)
      assert {:error, :not_found} = ComposeFile.get_service(compose, "unknown")
    end
  end
end
