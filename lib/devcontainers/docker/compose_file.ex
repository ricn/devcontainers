defmodule Devcontainers.Docker.ComposeFile do
  @moduledoc """
  Parser for Docker Compose YAML files.

  Extracts service definitions from compose files, including:
  - Service names and images
  - Environment variables
  - Port mappings
  - Labels

  ## Examples

      iex> {:ok, compose} = Devcontainers.Docker.ComposeFile.parse("compose.yml")
      iex> Map.keys(compose.services)
      ["db", "redis"]

  """

  @type port_mapping :: %{
          host: non_neg_integer() | nil,
          container: non_neg_integer(),
          protocol: String.t()
        }

  @type service :: %{
          name: String.t(),
          image: String.t() | nil,
          environment: %{String.t() => String.t()},
          ports: [port_mapping()],
          labels: %{String.t() => String.t()},
          depends_on: [String.t()],
          profiles: [String.t()]
        }

  @type t :: %__MODULE__{
          version: String.t() | nil,
          services: %{String.t() => service()},
          raw: map()
        }

  defstruct version: nil, services: %{}, raw: %{}

  @ignore_labels [
    "devcontainers.ignore"
  ]

  @doc """
  Parses a Docker Compose file from the given path.

  ## Examples

      iex> Devcontainers.Docker.ComposeFile.parse("compose.yml")
      {:ok, %Devcontainers.Docker.ComposeFile{...}}

      iex> Devcontainers.Docker.ComposeFile.parse("nonexistent.yml")
      {:error, :enoent}

  """
  @spec parse(String.t()) :: {:ok, t()} | {:error, term()}
  def parse(path) do
    with {:ok, content} <- File.read(path),
         {:ok, yaml} <- YamlElixir.read_from_string(content) do
      {:ok, parse_yaml(yaml)}
    end
  end

  @doc """
  Parses Docker Compose YAML content from a string.

  ## Examples

      iex> yaml = \"\"\"
      ...> services:
      ...>   db:
      ...>     image: postgres:15
      ...> \"\"\"
      iex> {:ok, compose} = Devcontainers.Docker.ComposeFile.parse_string(yaml)
      iex> compose.services["db"].image
      "postgres:15"

  """
  @spec parse_string(String.t()) :: {:ok, t()} | {:error, term()}
  def parse_string(content) do
    case YamlElixir.read_from_string(content) do
      {:ok, yaml} -> {:ok, parse_yaml(yaml)}
      error -> error
    end
  end

  @doc """
  Returns a list of services that should not be ignored.

  Filters out services that have ignore labels set to "true".

  ## Examples

      iex> {:ok, compose} = Devcontainers.Docker.ComposeFile.parse("compose.yml")
      iex> Devcontainers.Docker.ComposeFile.active_services(compose)
      [%{name: "db", image: "postgres:15", ...}]

  """
  @spec active_services(t()) :: [service()]
  def active_services(%__MODULE__{services: services}) do
    services
    |> Map.values()
    |> Enum.reject(&ignored?/1)
  end

  @doc """
  Checks if a service should be ignored based on its labels.
  """
  @spec ignored?(service()) :: boolean()
  def ignored?(%{labels: labels}) do
    Enum.any?(@ignore_labels, fn label ->
      Map.get(labels, label) in ["true", "1", true]
    end)
  end

  @doc """
  Gets a service by name.

  ## Examples

      iex> {:ok, compose} = Devcontainers.Docker.ComposeFile.parse("compose.yml")
      iex> Devcontainers.Docker.ComposeFile.get_service(compose, "db")
      {:ok, %{name: "db", image: "postgres:15", ...}}

  """
  @spec get_service(t(), String.t()) :: {:ok, service()} | {:error, :not_found}
  def get_service(%__MODULE__{services: services}, name) do
    case Map.fetch(services, name) do
      {:ok, service} -> {:ok, service}
      :error -> {:error, :not_found}
    end
  end

  # Private functions

  defp parse_yaml(yaml) when is_map(yaml) do
    version = Map.get(yaml, "version")
    services_map = Map.get(yaml, "services", %{})

    services =
      services_map
      |> Enum.map(fn {name, config} ->
        {name, parse_service(name, config || %{})}
      end)
      |> Map.new()

    %__MODULE__{
      version: version,
      services: services,
      raw: yaml
    }
  end

  defp parse_service(name, config) when is_map(config) do
    %{
      name: name,
      image: Map.get(config, "image"),
      environment: parse_environment(Map.get(config, "environment", [])),
      ports: parse_ports(Map.get(config, "ports", [])),
      labels: parse_labels(Map.get(config, "labels", [])),
      depends_on: parse_depends_on(Map.get(config, "depends_on", [])),
      profiles: Map.get(config, "profiles", [])
    }
  end

  defp parse_environment(env) when is_list(env) do
    Enum.reduce(env, %{}, fn
      item, acc when is_binary(item) ->
        case String.split(item, "=", parts: 2) do
          [key, value] -> Map.put(acc, key, value)
          [key] -> Map.put(acc, key, "")
        end

      item, acc when is_map(item) ->
        Map.merge(acc, stringify_map(item))
    end)
  end

  defp parse_environment(env) when is_map(env) do
    stringify_map(env)
  end

  defp parse_environment(_), do: %{}

  defp stringify_map(map) do
    Map.new(map, fn {k, v} -> {to_string(k), to_string(v)} end)
  end

  defp parse_ports(ports) when is_list(ports) do
    Enum.map(ports, &parse_port/1)
  end

  defp parse_ports(_), do: []

  defp parse_port(port) when is_integer(port) do
    %{host: nil, container: port, protocol: "tcp"}
  end

  defp parse_port(port) when is_binary(port) do
    # Handle formats: "8080", "8080:80", "8080:80/udp", "127.0.0.1:8080:80"
    {port_str, protocol} =
      case String.split(port, "/") do
        [p, proto] -> {p, proto}
        [p] -> {p, "tcp"}
      end

    parts = String.split(port_str, ":")

    case parts do
      [container] ->
        %{host: nil, container: parse_int(container), protocol: protocol}

      [host, container] ->
        %{host: parse_int(host), container: parse_int(container), protocol: protocol}

      [_ip, host, container] ->
        %{host: parse_int(host), container: parse_int(container), protocol: protocol}
    end
  end

  defp parse_port(%{"target" => target} = port_map) do
    %{
      host: Map.get(port_map, "published"),
      container: target,
      protocol: Map.get(port_map, "protocol", "tcp")
    }
  end

  defp parse_int(str) when is_binary(str) do
    case Integer.parse(str) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp parse_int(int) when is_integer(int), do: int

  defp parse_labels(labels) when is_list(labels) do
    Enum.reduce(labels, %{}, fn
      item, acc when is_binary(item) ->
        case String.split(item, "=", parts: 2) do
          [key, value] -> Map.put(acc, key, value)
          [key] -> Map.put(acc, key, "")
        end

      item, acc when is_map(item) ->
        Map.merge(acc, stringify_map(item))
    end)
  end

  defp parse_labels(labels) when is_map(labels) do
    stringify_map(labels)
  end

  defp parse_labels(_), do: %{}

  defp parse_depends_on(depends) when is_list(depends), do: depends
  defp parse_depends_on(depends) when is_map(depends), do: Map.keys(depends)
  defp parse_depends_on(_), do: []
end
