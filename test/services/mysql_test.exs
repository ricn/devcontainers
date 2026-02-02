defmodule Devcontainers.Services.MySQLTest do
  use ExUnit.Case, async: true

  alias Devcontainers.Services.MySQL

  describe "match?/1" do
    test "matches mysql image" do
      assert MySQL.match?("mysql")
      assert MySQL.match?("mysql:8")
      assert MySQL.match?("mysql:8.0")
      assert MySQL.match?("mysql:latest")
    end

    test "matches mariadb image" do
      assert MySQL.match?("mariadb")
      assert MySQL.match?("mariadb:10")
      assert MySQL.match?("mariadb:11.2")
    end

    test "does not match other images" do
      refute MySQL.match?("postgres:15")
      refute MySQL.match?("redis:7")
      refute MySQL.match?("mymysql:latest")
    end
  end

  describe "connection_details/2" do
    test "extracts credentials with MYSQL_USER" do
      service = %{
        name: "db",
        image: "mysql:8",
        environment: %{
          "MYSQL_USER" => "myuser",
          "MYSQL_PASSWORD" => "mysecret",
          "MYSQL_DATABASE" => "mydb"
        },
        ports: [],
        labels: %{},
        depends_on: [],
        profiles: []
      }

      container_info = %{host: "localhost", port: 3306, ports: %{3306 => 3306}}
      details = MySQL.connection_details(service, container_info)

      assert details.type == :mysql
      assert details.username == "myuser"
      assert details.password == "mysecret"
      assert details.database == "mydb"
    end

    test "uses root with MYSQL_ROOT_PASSWORD" do
      service = %{
        name: "db",
        image: "mysql:8",
        environment: %{
          "MYSQL_ROOT_PASSWORD" => "rootsecret",
          "MYSQL_DATABASE" => "mydb"
        },
        ports: [],
        labels: %{},
        depends_on: [],
        profiles: []
      }

      container_info = %{host: "localhost", port: 3306, ports: %{3306 => 3306}}
      details = MySQL.connection_details(service, container_info)

      assert details.username == "root"
      assert details.password == "rootsecret"
    end

    test "returns :mariadb type for mariadb image" do
      service = %{
        name: "db",
        image: "mariadb:11",
        environment: %{
          "MYSQL_ROOT_PASSWORD" => "secret"
        },
        ports: [],
        labels: %{},
        depends_on: [],
        profiles: []
      }

      container_info = %{host: "localhost", port: 3306, ports: %{3306 => 3306}}
      details = MySQL.connection_details(service, container_info)

      assert details.type == :mariadb
    end
  end

  describe "health_check_port/1" do
    test "returns 3306" do
      assert MySQL.health_check_port(%{}) == 3306
    end
  end
end
