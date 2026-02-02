defmodule Devcontainers.Lifecycle.Manager do
  @moduledoc """
  GenServer managing the Docker Compose service lifecycle.

  Handles starting containers when the application starts, waiting for
  services to be ready, extracting connection details, and stopping
  containers when the application shuts down.

  ## Lifecycle Modes

  - `:start_and_stop` - Start services on init, stop on terminate (default)
  - `:start_only` - Start services on init, don't stop on terminate
  - `:none` - Don't automatically start or stop services

  ## State

  The manager tracks:
  - Configuration
  - Running services and their connection details
  - Whether services were started by this process
  """

  use GenServer

  require Logger

  alias Devcontainers.Config
  alias Devcontainers.Docker.{Compose, ComposeFile, HealthCheck}
  alias Devcontainers.Services.{Registry, ConnectionDetails}

  @type state :: %{
          config: Config.t(),
          services: %{String.t() => ConnectionDetails.t()},
          started: boolean(),
          compose_file: ComposeFile.t() | nil
        }

  # Client API

  @doc """
  Starts the lifecycle manager.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Manually starts Docker Compose services.

  Returns `:ok` on success or `{:error, reason}` on failure.
  """
  @spec start_services(keyword()) :: :ok | {:error, term()}
  def start_services(opts \\ []) do
    GenServer.call(__MODULE__, {:start_services, opts}, :infinity)
  end

  @doc """
  Stops Docker Compose services.
  """
  @spec stop_services() :: :ok | {:error, term()}
  def stop_services do
    GenServer.call(__MODULE__, :stop_services, :infinity)
  end

  @doc """
  Returns the current status of services.

  ## Examples

      iex> Devcontainers.Lifecycle.Manager.status()
      %{
        started: true,
        services: %{
          "db" => %ConnectionDetails{type: :postgres, ...}
        }
      }

  """
  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @doc """
  Returns connection details for a specific service.

  ## Examples

      iex> Devcontainers.Lifecycle.Manager.connection_details("db")
      {:ok, %ConnectionDetails{type: :postgres, host: "localhost", port: 5432, ...}}

  """
  @spec connection_details(String.t()) :: {:ok, ConnectionDetails.t()} | {:error, :not_found}
  def connection_details(service_name) do
    GenServer.call(__MODULE__, {:connection_details, service_name})
  end

  @doc """
  Returns all connection details keyed by service name.
  """
  @spec all_connection_details() :: %{String.t() => ConnectionDetails.t()}
  def all_connection_details do
    GenServer.call(__MODULE__, :all_connection_details)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    config = Config.read()

    state = %{
      config: config,
      services: %{},
      started: false,
      compose_file: nil
    }

    if should_auto_start?(config) do
      send(self(), :auto_start)
    end

    {:ok, state}
  end

  @impl true
  def handle_call({:start_services, opts}, _from, state) do
    case do_start_services(state, opts) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} = error ->
        Logger.error("Failed to start services: #{inspect(reason)}")
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:stop_services, _from, state) do
    case do_stop_services(state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} = error ->
        Logger.error("Failed to stop services: #{inspect(reason)}")
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      started: state.started,
      services: state.services,
      compose_file: state.config.compose_file
    }

    {:reply, status, state}
  end

  @impl true
  def handle_call({:connection_details, service_name}, _from, state) do
    reply =
      case Map.fetch(state.services, service_name) do
        {:ok, details} -> {:ok, details}
        :error -> {:error, :not_found}
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_call(:all_connection_details, _from, state) do
    {:reply, state.services, state}
  end

  @impl true
  def handle_info(:auto_start, state) do
    case do_start_services(state, []) do
      {:ok, new_state} ->
        Logger.info("Devcontainers: Services started successfully")
        {:noreply, new_state}

      {:error, reason} ->
        Logger.error("Devcontainers: Failed to auto-start services: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def terminate(_reason, state) do
    if state.started and state.config.lifecycle == :start_and_stop do
      Logger.info("Devcontainers: Stopping services...")
      do_stop_services(state)
    end

    :ok
  end

  # Private functions

  defp should_auto_start?(config) do
    config.enabled and
      config.lifecycle in [:start_and_stop, :start_only] and
      config.compose_file != nil and
      Compose.available?() and
      not skip_in_current_env?(config)
  end

  defp skip_in_current_env?(config) do
    config.skip_in_tests and mix_env() == :test
  end

  defp mix_env do
    if function_exported?(Mix, :env, 0), do: Mix.env(), else: :prod
  end

  defp do_start_services(state, opts) do
    compose_file_path = Keyword.get(opts, :file) || state.config.compose_file

    if compose_file_path == nil do
      {:error, :no_compose_file}
    else
      with {:ok, compose} <- ComposeFile.parse(compose_file_path),
           :ok <- start_compose(compose_file_path, state.config, opts),
           {:ok, services} <- build_connection_details(compose, compose_file_path, state.config) do
        set_environment_variables(services)

        {:ok,
         %{
           state
           | services: services,
             started: true,
             compose_file: compose
         }}
      end
    end
  end

  defp start_compose(file, config, opts) do
    compose_opts = [
      file: file,
      project_name: Keyword.get(opts, :project_name) || config.project_name,
      profiles: Keyword.get(opts, :profiles) || config.profiles,
      detach: true,
      wait: true
    ]

    Logger.info("Devcontainers: Starting services from #{file}...")

    Compose.up(compose_opts)
  end

  defp build_connection_details(compose, file, config) do
    active_services = ComposeFile.active_services(compose)

    results =
      Enum.reduce_while(active_services, {:ok, %{}}, fn service, {:ok, acc} ->
        case build_service_details(service, file, config) do
          {:ok, details} ->
            {:cont, {:ok, Map.put(acc, service.name, details)}}

          {:skip, reason} ->
            Logger.debug("Skipping service #{service.name}: #{reason}")
            {:cont, {:ok, acc}}

          {:error, reason} ->
            {:halt, {:error, {service.name, reason}}}
        end
      end)

    results
  end

  defp build_service_details(service, file, config) do
    image = service.image

    if image == nil do
      {:skip, "no image specified"}
    else
      case Registry.find_handler(image) do
        {:ok, handler} ->
          with {:ok, container_info} <- get_container_info(service, file, config),
               :ok <- wait_for_service(handler, service, container_info, config) do
            details = handler.connection_details(service, container_info)
            {:ok, details}
          end

        {:error, :no_handler} ->
          {:skip, "no handler for image #{image}"}
      end
    end
  end

  defp get_container_info(service, file, config) do
    compose_opts = [
      file: file,
      project_name: config.project_name,
      profiles: config.profiles
    ]

    case Compose.ps(compose_opts) do
      {:ok, containers} ->
        container =
          Enum.find(containers, fn c ->
            Map.get(c, "Service") == service.name
          end)

        if container do
          ports = extract_ports(container)
          host = "localhost"

          main_port =
            case Map.values(ports) do
              [port | _] -> port
              [] -> nil
            end

          {:ok, %{host: host, port: main_port, ports: ports}}
        else
          {:error, :container_not_found}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_ports(container) do
    publishers = Map.get(container, "Publishers", [])

    publishers
    |> Enum.filter(fn p -> Map.get(p, "PublishedPort", 0) > 0 end)
    |> Enum.map(fn p ->
      {Map.get(p, "TargetPort"), Map.get(p, "PublishedPort")}
    end)
    |> Map.new()
  end

  defp wait_for_service(handler, service, container_info, config) do
    port_to_check = handler.health_check_port(service)
    host_port = Map.get(container_info.ports, port_to_check)

    if host_port do
      Logger.debug("Waiting for #{service.name} on port #{host_port}...")

      opts = [timeout: config.readiness_timeout]

      # Use custom ready check if handler implements it
      if function_exported?(handler, :ready?, 3) do
        wait_with_custom_check(handler, container_info.host, host_port, opts)
      else
        HealthCheck.wait_for_tcp(container_info.host, host_port, opts)
      end
    else
      Logger.warning("No published port found for #{service.name}:#{port_to_check}")
      :ok
    end
  end

  defp wait_with_custom_check(handler, host, port, opts) do
    timeout = Keyword.get(opts, :timeout, 60_000)
    interval = Keyword.get(opts, :interval, 500)
    deadline = System.monotonic_time(:millisecond) + timeout

    do_wait_with_custom_check(handler, host, port, deadline, interval)
  end

  defp do_wait_with_custom_check(handler, host, port, deadline, interval) do
    if handler.ready?(host, port, []) do
      :ok
    else
      now = System.monotonic_time(:millisecond)

      if now >= deadline do
        {:error, :timeout}
      else
        Process.sleep(interval)
        do_wait_with_custom_check(handler, host, port, deadline, interval)
      end
    end
  end

  defp set_environment_variables(services) do
    Enum.each(services, fn {name, details} ->
      env_vars = ConnectionDetails.to_env_vars(details, name)

      Enum.each(env_vars, fn {key, value} ->
        System.put_env(key, value)
        Logger.debug("Set #{key}=#{mask_sensitive(key, value)}")
      end)
    end)
  end

  defp mask_sensitive(key, value) do
    if String.contains?(String.downcase(key), ["password", "secret", "token"]) do
      "****"
    else
      value
    end
  end

  defp do_stop_services(state) do
    if state.config.compose_file do
      compose_opts = [
        file: state.config.compose_file,
        project_name: state.config.project_name,
        profiles: state.config.profiles
      ]

      case Compose.stop(compose_opts) do
        :ok ->
          {:ok, %{state | services: %{}, started: false}}

        error ->
          error
      end
    else
      {:ok, state}
    end
  end
end
