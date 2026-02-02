defmodule Devcontainers.Services.ConnectionDetails do
  @moduledoc """
  Struct representing connection details for a service.

  Contains all the information needed to connect to a running service,
  including host, port, credentials, and service-specific options.

  ## Examples

      iex> details = %Devcontainers.Services.ConnectionDetails{
      ...>   type: :postgres,
      ...>   host: "localhost",
      ...>   port: 5432,
      ...>   username: "postgres",
      ...>   password: "secret",
      ...>   database: "myapp_dev"
      ...> }
      iex> Devcontainers.Services.ConnectionDetails.to_url(details)
      "postgres://postgres:secret@localhost:5432/myapp_dev"

  """

  @type t :: %__MODULE__{
          type: atom(),
          host: String.t(),
          port: non_neg_integer(),
          username: String.t() | nil,
          password: String.t() | nil,
          database: String.t() | nil,
          options: map()
        }

  defstruct type: nil,
            host: "localhost",
            port: nil,
            username: nil,
            password: nil,
            database: nil,
            options: %{}

  @doc """
  Generates a connection URL based on the service type.

  Automatically chooses the correct URL format based on the service type.

  ## Examples

      iex> details = %ConnectionDetails{type: :postgres, host: "localhost", port: 5432, username: "postgres", password: "secret", database: "myapp"}
      iex> ConnectionDetails.to_url(details)
      "postgres://postgres:secret@localhost:5432/myapp"

      iex> details = %ConnectionDetails{type: :redis, host: "localhost", port: 6379}
      iex> ConnectionDetails.to_url(details)
      "redis://localhost:6379"

  """
  @spec to_url(t()) :: String.t()
  def to_url(%__MODULE__{type: type} = details) do
    case type do
      t when t in [:postgres, :postgresql] -> to_database_url(details)
      t when t in [:mysql, :mariadb] -> to_database_url(details)
      :redis -> to_redis_url(details)
      :rabbitmq -> to_amqp_url(details)
      :mongodb -> to_mongodb_url(details)
      :elasticsearch -> to_elasticsearch_url(details)
      :kafka -> to_kafka_url(details)
      _ -> to_generic_url(details)
    end
  end

  @doc """
  Generates an Ecto-compatible database URL.

  Works for PostgreSQL, MySQL, and MariaDB.

  ## Examples

      iex> details = %ConnectionDetails{type: :postgres, host: "localhost", port: 5432, username: "postgres", password: "secret", database: "myapp"}
      iex> ConnectionDetails.to_database_url(details)
      "postgres://postgres:secret@localhost:5432/myapp"

      iex> details = %ConnectionDetails{type: :mysql, host: "localhost", port: 3306, username: "root", password: "secret", database: "myapp"}
      iex> ConnectionDetails.to_database_url(details)
      "mysql://root:secret@localhost:3306/myapp"

  """
  @spec to_database_url(t()) :: String.t()
  def to_database_url(%__MODULE__{} = details) do
    scheme =
      case details.type do
        :postgres -> "postgres"
        :postgresql -> "postgres"
        :mysql -> "mysql"
        :mariadb -> "mysql"
        other -> to_string(other)
      end

    auth = build_auth(details.username, details.password)
    database = if details.database, do: "/#{details.database}", else: ""
    query = build_query_string(details.options)

    "#{scheme}://#{auth}#{details.host}:#{details.port}#{database}#{query}"
  end

  @doc """
  Generates a Redis URL.

  ## Examples

      iex> details = %ConnectionDetails{type: :redis, host: "localhost", port: 6379}
      iex> ConnectionDetails.to_redis_url(details)
      "redis://localhost:6379"

      iex> details = %ConnectionDetails{type: :redis, host: "localhost", port: 6379, password: "secret", database: "1"}
      iex> ConnectionDetails.to_redis_url(details)
      "redis://:secret@localhost:6379/1"

  """
  @spec to_redis_url(t()) :: String.t()
  def to_redis_url(%__MODULE__{} = details) do
    auth =
      if details.password do
        ":#{URI.encode_www_form(details.password)}@"
      else
        ""
      end

    database = if details.database, do: "/#{details.database}", else: ""

    "redis://#{auth}#{details.host}:#{details.port}#{database}"
  end

  @doc """
  Generates an AMQP URL for RabbitMQ.

  ## Examples

      iex> details = %ConnectionDetails{type: :rabbitmq, host: "localhost", port: 5672, username: "guest", password: "guest"}
      iex> ConnectionDetails.to_amqp_url(details)
      "amqp://guest:guest@localhost:5672"

      iex> details = %ConnectionDetails{type: :rabbitmq, host: "localhost", port: 5672, username: "guest", password: "guest", database: "myvhost"}
      iex> ConnectionDetails.to_amqp_url(details)
      "amqp://guest:guest@localhost:5672/myvhost"

  """
  @spec to_amqp_url(t()) :: String.t()
  def to_amqp_url(%__MODULE__{} = details) do
    auth = build_auth(details.username, details.password)
    vhost = if details.database, do: "/#{URI.encode_www_form(details.database)}", else: ""

    "amqp://#{auth}#{details.host}:#{details.port}#{vhost}"
  end

  @doc """
  Generates a MongoDB connection URL.

  ## Examples

      iex> details = %ConnectionDetails{type: :mongodb, host: "localhost", port: 27017}
      iex> ConnectionDetails.to_mongodb_url(details)
      "mongodb://localhost:27017"

      iex> details = %ConnectionDetails{type: :mongodb, host: "localhost", port: 27017, username: "admin", password: "secret", database: "myapp"}
      iex> ConnectionDetails.to_mongodb_url(details)
      "mongodb://admin:secret@localhost:27017/myapp"

  """
  @spec to_mongodb_url(t()) :: String.t()
  def to_mongodb_url(%__MODULE__{} = details) do
    auth = build_auth(details.username, details.password)
    database = if details.database, do: "/#{details.database}", else: ""
    query = build_query_string(details.options)

    "mongodb://#{auth}#{details.host}:#{details.port}#{database}#{query}"
  end

  @doc """
  Generates an Elasticsearch URL.

  ## Examples

      iex> details = %ConnectionDetails{type: :elasticsearch, host: "localhost", port: 9200}
      iex> ConnectionDetails.to_elasticsearch_url(details)
      "http://localhost:9200"

      iex> details = %ConnectionDetails{type: :elasticsearch, host: "localhost", port: 9200, username: "elastic", password: "secret"}
      iex> ConnectionDetails.to_elasticsearch_url(details)
      "http://elastic:secret@localhost:9200"

  """
  @spec to_elasticsearch_url(t()) :: String.t()
  def to_elasticsearch_url(%__MODULE__{} = details) do
    scheme = Map.get(details.options, :scheme, "http")
    auth = build_auth(details.username, details.password)

    "#{scheme}://#{auth}#{details.host}:#{details.port}"
  end

  @doc """
  Generates a Kafka bootstrap servers string.

  ## Examples

      iex> details = %ConnectionDetails{type: :kafka, host: "localhost", port: 9092}
      iex> ConnectionDetails.to_kafka_url(details)
      "localhost:9092"

  """
  @spec to_kafka_url(t()) :: String.t()
  def to_kafka_url(%__MODULE__{} = details) do
    "#{details.host}:#{details.port}"
  end

  @doc """
  Returns environment variable mappings for this connection.

  Generates a map of environment variable names to values based on
  the service type.

  ## Examples

      iex> details = %ConnectionDetails{type: :postgres, host: "localhost", port: 5432, username: "postgres", password: "secret", database: "myapp"}
      iex> ConnectionDetails.to_env_vars(details, "db")
      %{
        "DATABASE_URL" => "postgres://postgres:secret@localhost:5432/myapp",
        "DB_HOST" => "localhost",
        "DB_PORT" => "5432",
        "DB_USER" => "postgres",
        "DB_PASSWORD" => "secret",
        "DB_NAME" => "myapp"
      }

  """
  @spec to_env_vars(t(), String.t()) :: map()
  def to_env_vars(%__MODULE__{type: type} = details, service_name) do
    prefix = String.upcase(service_name)
    url = to_url(details)

    base_vars = %{
      "#{prefix}_HOST" => details.host,
      "#{prefix}_PORT" => to_string(details.port)
    }

    base_vars =
      if details.username do
        Map.put(base_vars, "#{prefix}_USER", details.username)
      else
        base_vars
      end

    base_vars =
      if details.password do
        Map.put(base_vars, "#{prefix}_PASSWORD", details.password)
      else
        base_vars
      end

    base_vars =
      if details.database do
        Map.put(base_vars, "#{prefix}_NAME", details.database)
      else
        base_vars
      end

    # Add type-specific URL environment variable
    case type do
      t when t in [:postgres, :postgresql, :mysql, :mariadb] ->
        Map.put(base_vars, "DATABASE_URL", url)

      :redis ->
        Map.put(base_vars, "REDIS_URL", url)

      :rabbitmq ->
        Map.put(base_vars, "RABBITMQ_URL", url)

      :mongodb ->
        Map.put(base_vars, "MONGODB_URL", url)

      :elasticsearch ->
        Map.put(base_vars, "ELASTICSEARCH_URL", url)

      :kafka ->
        Map.put(base_vars, "KAFKA_BOOTSTRAP_SERVERS", url)

      _ ->
        Map.put(base_vars, "#{prefix}_URL", url)
    end
  end

  # Private functions

  defp build_auth(nil, _), do: ""
  defp build_auth(_, nil), do: ""

  defp build_auth(username, password) do
    "#{URI.encode_www_form(username)}:#{URI.encode_www_form(password)}@"
  end

  defp build_query_string(options) when map_size(options) == 0, do: ""

  defp build_query_string(options) do
    query =
      options
      |> Enum.reject(fn {k, _} -> k == :scheme end)
      |> Enum.map(fn {k, v} -> "#{k}=#{URI.encode_www_form(to_string(v))}" end)
      |> Enum.join("&")

    if query == "", do: "", else: "?#{query}"
  end

  defp to_generic_url(%__MODULE__{} = details) do
    auth = build_auth(details.username, details.password)
    "#{details.type}://#{auth}#{details.host}:#{details.port}"
  end
end
