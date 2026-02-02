defmodule Devcontainers.Config do
  @moduledoc """
  Configuration reader for Devcontainers.

  Configuration can be provided via application environment or system environment variables.

  ## Application Configuration

      # config/dev.exs
      config :devcontainers,
        enabled: true,
        compose_file: "compose.yml",
        lifecycle: :start_and_stop,
        readiness_timeout: 60_000,
        skip_in_tests: false,
        profiles: [],
        project_name: nil

  ## Environment Variables

  Environment variables take precedence over application configuration:

  - `DEVCONTAINERS_SKIP=true` - Skip entirely (same as `enabled: false`)
  - `DEVCONTAINERS_ENABLED=false` - Disable the package
  - `DEVCONTAINERS_COMPOSE_FILE` - Override compose file path

  ## Lifecycle Options

  - `:start_and_stop` - Start services on app start, stop on app shutdown (default)
  - `:start_only` - Start services but don't stop them on shutdown
  - `:none` - Don't manage lifecycle automatically
  """

  @type lifecycle :: :start_and_stop | :start_only | :none

  @type t :: %__MODULE__{
          enabled: boolean(),
          compose_file: String.t() | nil,
          lifecycle: lifecycle(),
          readiness_timeout: pos_integer(),
          skip_in_tests: boolean(),
          profiles: [String.t()],
          project_name: String.t() | nil
        }

  defstruct enabled: true,
            compose_file: nil,
            lifecycle: :start_and_stop,
            readiness_timeout: 60_000,
            skip_in_tests: false,
            profiles: [],
            project_name: nil

  @doc """
  Reads the current configuration from application environment and system environment.

  Returns a `%Devcontainers.Config{}` struct with all resolved configuration values.

  ## Examples

      iex> config = Devcontainers.Config.read()
      iex> is_boolean(config.enabled)
      true

  """
  @spec read() :: t()
  def read do
    %__MODULE__{
      enabled: read_enabled(),
      compose_file: read_compose_file(),
      lifecycle: read_lifecycle(),
      readiness_timeout: read_readiness_timeout(),
      skip_in_tests: read_skip_in_tests(),
      profiles: read_profiles(),
      project_name: read_project_name()
    }
  end

  @doc """
  Returns whether devcontainers is enabled based on configuration and environment.

  Checks (in order of precedence):
  1. `DEVCONTAINERS_SKIP` environment variable
  2. `DEVCONTAINERS_ENABLED` environment variable
  3. Application configuration `:enabled` key
  4. Default: `true` in `:dev` and `:test`, `false` otherwise
  """
  @spec enabled?() :: boolean()
  def enabled? do
    read_enabled()
  end

  @doc """
  Returns the path to the compose file.

  If not explicitly configured, attempts to auto-detect by looking for:
  1. `compose.yml`
  2. `compose.yaml`
  3. `docker-compose.yml`
  4. `docker-compose.yaml`
  """
  @spec compose_file() :: String.t() | nil
  def compose_file do
    read_compose_file()
  end

  # Private functions

  defp read_enabled do
    cond do
      System.get_env("DEVCONTAINERS_SKIP") in ["true", "1"] ->
        false

      env_enabled = System.get_env("DEVCONTAINERS_ENABLED") ->
        env_enabled not in ["false", "0"]

      app_enabled = Application.get_env(:devcontainers, :enabled) ->
        app_enabled

      true ->
        default_enabled()
    end
  end

  defp default_enabled do
    case mix_env() do
      :dev -> true
      :test -> true
      _ -> false
    end
  end

  defp mix_env do
    if function_exported?(Mix, :env, 0) do
      Mix.env()
    else
      :prod
    end
  end

  defp read_compose_file do
    System.get_env("DEVCONTAINERS_COMPOSE_FILE") ||
      Application.get_env(:devcontainers, :compose_file) ||
      auto_detect_compose_file()
  end

  defp auto_detect_compose_file do
    candidates = [
      "compose.yml",
      "compose.yaml",
      "docker-compose.yml",
      "docker-compose.yaml"
    ]

    Enum.find(candidates, &File.exists?/1)
  end

  defp read_lifecycle do
    case Application.get_env(:devcontainers, :lifecycle, :start_and_stop) do
      :start_and_stop -> :start_and_stop
      :start_only -> :start_only
      :none -> :none
      other -> raise ArgumentError, "Invalid lifecycle option: #{inspect(other)}"
    end
  end

  defp read_readiness_timeout do
    Application.get_env(:devcontainers, :readiness_timeout, 60_000)
  end

  defp read_skip_in_tests do
    Application.get_env(:devcontainers, :skip_in_tests, false)
  end

  defp read_profiles do
    Application.get_env(:devcontainers, :profiles, [])
  end

  defp read_project_name do
    Application.get_env(:devcontainers, :project_name)
  end
end
