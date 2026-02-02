defmodule Devcontainers.Services.ConnectionDetailsTest do
  use ExUnit.Case, async: true

  alias Devcontainers.Services.ConnectionDetails

  describe "to_database_url/1" do
    test "generates PostgreSQL URL" do
      details = %ConnectionDetails{
        type: :postgres,
        host: "localhost",
        port: 5432,
        username: "postgres",
        password: "secret",
        database: "myapp_dev"
      }

      assert ConnectionDetails.to_database_url(details) ==
               "postgres://postgres:secret@localhost:5432/myapp_dev"
    end

    test "generates MySQL URL" do
      details = %ConnectionDetails{
        type: :mysql,
        host: "localhost",
        port: 3306,
        username: "root",
        password: "secret",
        database: "myapp_dev"
      }

      assert ConnectionDetails.to_database_url(details) ==
               "mysql://root:secret@localhost:3306/myapp_dev"
    end

    test "encodes special characters in credentials" do
      details = %ConnectionDetails{
        type: :postgres,
        host: "localhost",
        port: 5432,
        username: "user@domain",
        password: "p@ss:word/123",
        database: "myapp"
      }

      url = ConnectionDetails.to_database_url(details)
      assert url =~ "user%40domain"
      assert url =~ "p%40ss%3Aword%2F123"
    end
  end

  describe "to_redis_url/1" do
    test "generates simple Redis URL" do
      details = %ConnectionDetails{
        type: :redis,
        host: "localhost",
        port: 6379
      }

      assert ConnectionDetails.to_redis_url(details) == "redis://localhost:6379"
    end

    test "generates Redis URL with password" do
      details = %ConnectionDetails{
        type: :redis,
        host: "localhost",
        port: 6379,
        password: "secret"
      }

      assert ConnectionDetails.to_redis_url(details) == "redis://:secret@localhost:6379"
    end

    test "generates Redis URL with database" do
      details = %ConnectionDetails{
        type: :redis,
        host: "localhost",
        port: 6379,
        password: "secret",
        database: "1"
      }

      assert ConnectionDetails.to_redis_url(details) == "redis://:secret@localhost:6379/1"
    end
  end

  describe "to_amqp_url/1" do
    test "generates RabbitMQ URL" do
      details = %ConnectionDetails{
        type: :rabbitmq,
        host: "localhost",
        port: 5672,
        username: "guest",
        password: "guest"
      }

      assert ConnectionDetails.to_amqp_url(details) == "amqp://guest:guest@localhost:5672"
    end

    test "generates RabbitMQ URL with vhost" do
      details = %ConnectionDetails{
        type: :rabbitmq,
        host: "localhost",
        port: 5672,
        username: "myapp",
        password: "secret",
        database: "myvhost"
      }

      assert ConnectionDetails.to_amqp_url(details) ==
               "amqp://myapp:secret@localhost:5672/myvhost"
    end
  end

  describe "to_mongodb_url/1" do
    test "generates simple MongoDB URL" do
      details = %ConnectionDetails{
        type: :mongodb,
        host: "localhost",
        port: 27017
      }

      assert ConnectionDetails.to_mongodb_url(details) == "mongodb://localhost:27017"
    end

    test "generates MongoDB URL with auth" do
      details = %ConnectionDetails{
        type: :mongodb,
        host: "localhost",
        port: 27017,
        username: "admin",
        password: "secret",
        database: "myapp"
      }

      assert ConnectionDetails.to_mongodb_url(details) ==
               "mongodb://admin:secret@localhost:27017/myapp"
    end
  end

  describe "to_elasticsearch_url/1" do
    test "generates HTTP Elasticsearch URL" do
      details = %ConnectionDetails{
        type: :elasticsearch,
        host: "localhost",
        port: 9200
      }

      assert ConnectionDetails.to_elasticsearch_url(details) == "http://localhost:9200"
    end

    test "generates Elasticsearch URL with auth" do
      details = %ConnectionDetails{
        type: :elasticsearch,
        host: "localhost",
        port: 9200,
        username: "elastic",
        password: "secret"
      }

      assert ConnectionDetails.to_elasticsearch_url(details) ==
               "http://elastic:secret@localhost:9200"
    end

    test "generates HTTPS Elasticsearch URL" do
      details = %ConnectionDetails{
        type: :elasticsearch,
        host: "localhost",
        port: 9200,
        username: "elastic",
        password: "secret",
        options: %{scheme: "https"}
      }

      assert ConnectionDetails.to_elasticsearch_url(details) ==
               "https://elastic:secret@localhost:9200"
    end
  end

  describe "to_kafka_url/1" do
    test "generates Kafka bootstrap servers" do
      details = %ConnectionDetails{
        type: :kafka,
        host: "localhost",
        port: 9092
      }

      assert ConnectionDetails.to_kafka_url(details) == "localhost:9092"
    end
  end

  describe "to_url/1" do
    test "auto-selects format based on type" do
      postgres = %ConnectionDetails{
        type: :postgres,
        host: "localhost",
        port: 5432,
        username: "postgres",
        password: "postgres",
        database: "myapp"
      }

      redis = %ConnectionDetails{type: :redis, host: "localhost", port: 6379}

      assert ConnectionDetails.to_url(postgres) =~ "postgres://"
      assert ConnectionDetails.to_url(redis) == "redis://localhost:6379"
    end
  end

  describe "to_env_vars/2" do
    test "generates environment variables for PostgreSQL" do
      details = %ConnectionDetails{
        type: :postgres,
        host: "localhost",
        port: 5432,
        username: "postgres",
        password: "secret",
        database: "myapp_dev"
      }

      env = ConnectionDetails.to_env_vars(details, "db")

      assert env["DATABASE_URL"] == "postgres://postgres:secret@localhost:5432/myapp_dev"
      assert env["DB_HOST"] == "localhost"
      assert env["DB_PORT"] == "5432"
      assert env["DB_USER"] == "postgres"
      assert env["DB_PASSWORD"] == "secret"
      assert env["DB_NAME"] == "myapp_dev"
    end

    test "generates environment variables for Redis" do
      details = %ConnectionDetails{
        type: :redis,
        host: "localhost",
        port: 6379
      }

      env = ConnectionDetails.to_env_vars(details, "redis")

      assert env["REDIS_URL"] == "redis://localhost:6379"
      assert env["REDIS_HOST"] == "localhost"
      assert env["REDIS_PORT"] == "6379"
    end

    test "uses uppercase service name as prefix" do
      details = %ConnectionDetails{
        type: :postgres,
        host: "localhost",
        port: 5432,
        username: "postgres",
        password: "secret",
        database: "myapp"
      }

      env = ConnectionDetails.to_env_vars(details, "primary_db")

      assert Map.has_key?(env, "PRIMARY_DB_HOST")
      assert Map.has_key?(env, "PRIMARY_DB_PORT")
    end
  end
end
