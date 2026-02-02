defmodule Devcontainers.Services.Registry do
  @moduledoc """
  Registry for service handlers.

  Manages the mapping between Docker image patterns and their corresponding
  service handlers. Handlers are matched in registration order, with custom
  handlers taking precedence over built-in ones.

  ## Built-in Handlers

  The following handlers are registered by default:

  - PostgreSQL: `postgres:*`
  - MySQL: `mysql:*`, `mariadb:*`
  - Redis: `redis:*`
  - RabbitMQ: `rabbitmq:*`
  - Kafka: `bitnami/kafka:*`, `confluentinc/cp-kafka:*`
  - MongoDB: `mongo:*`
  - Elasticsearch: `elasticsearch:*`, `docker.elastic.co/elasticsearch/*`

  ## Custom Handlers

  Register custom handlers to support internal images or override defaults:

      Devcontainers.Services.Registry.register(MyApp.Services.CustomDB)

  Custom handlers are prepended to the list and take precedence.
  """

  use GenServer

  alias Devcontainers.Services.{
    Postgres,
    MySQL,
    Redis,
    RabbitMQ,
    Kafka,
    MongoDB,
    Elasticsearch
  }

  @default_handlers [
    Postgres,
    MySQL,
    Redis,
    RabbitMQ,
    Kafka,
    MongoDB,
    Elasticsearch
  ]

  # Client API

  @doc """
  Starts the registry.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Registers a custom service handler.

  The handler must implement the `Devcontainers.Services.Service` behaviour.
  Custom handlers are prepended to the list and take precedence over
  previously registered handlers.

  ## Examples

      iex> Devcontainers.Services.Registry.register(MyApp.Services.CustomDB)
      :ok

  """
  @spec register(module()) :: :ok
  def register(handler) do
    GenServer.call(__MODULE__, {:register, handler})
  end

  @doc """
  Finds a handler that matches the given Docker image.

  Returns `{:ok, handler}` if a matching handler is found,
  or `{:error, :no_handler}` if no handler supports the image.

  ## Examples

      iex> Devcontainers.Services.Registry.find_handler("postgres:15")
      {:ok, Devcontainers.Services.Postgres}

      iex> Devcontainers.Services.Registry.find_handler("unknown-image:latest")
      {:error, :no_handler}

  """
  @spec find_handler(String.t()) :: {:ok, module()} | {:error, :no_handler}
  def find_handler(image) do
    GenServer.call(__MODULE__, {:find_handler, image})
  end

  @doc """
  Returns the list of registered handlers.

  ## Examples

      iex> Devcontainers.Services.Registry.list_handlers()
      [Devcontainers.Services.Postgres, Devcontainers.Services.MySQL, ...]

  """
  @spec list_handlers() :: [module()]
  def list_handlers do
    GenServer.call(__MODULE__, :list_handlers)
  end

  @doc """
  Clears all custom handlers and resets to defaults.

  Primarily useful for testing.
  """
  @spec reset() :: :ok
  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    {:ok, %{handlers: @default_handlers}}
  end

  @impl true
  def handle_call({:register, handler}, _from, state) do
    new_handlers = [handler | state.handlers]
    {:reply, :ok, %{state | handlers: new_handlers}}
  end

  @impl true
  def handle_call({:find_handler, image}, _from, state) do
    result =
      Enum.find(state.handlers, fn handler ->
        handler.match?(image)
      end)

    reply =
      if result do
        {:ok, result}
      else
        {:error, :no_handler}
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_call(:list_handlers, _from, state) do
    {:reply, state.handlers, state}
  end

  @impl true
  def handle_call(:reset, _from, _state) do
    {:reply, :ok, %{handlers: @default_handlers}}
  end
end
