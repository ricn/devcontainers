defmodule Mix.Tasks.Devcontainers.Down do
  @moduledoc """
  Stops and removes Docker Compose services.

  ## Usage

      mix devcontainers.down [options]

  ## Options

    * `--file` - Path to compose file (default: auto-detect)
    * `--volumes` - Also remove volumes
    * `--profile` - Profile to use (can be repeated)
    * `--project-name` - Set project name

  ## Examples

      mix devcontainers.down
      mix devcontainers.down --volumes
      mix devcontainers.down --file docker-compose.yml

  """
  @shortdoc "Stops and removes Docker Compose services"

  use Mix.Task

  alias Devcontainers.Docker.Compose
  alias Devcontainers.Config

  @switches [
    file: :string,
    volumes: :boolean,
    profile: :keep,
    project_name: :string
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: @switches)

    unless Compose.available?() do
      Mix.shell().error("Docker Compose is not available.")
      exit({:shutdown, 1})
    end

    config = Config.read()
    file = Keyword.get(opts, :file) || config.compose_file

    unless file do
      Mix.shell().error("No compose file found.")
      exit({:shutdown, 1})
    end

    volumes = Keyword.get(opts, :volumes, false)

    profiles =
      opts
      |> Keyword.get_values(:profile)
      |> case do
        [] -> config.profiles
        p -> p
      end

    project_name = Keyword.get(opts, :project_name) || config.project_name

    action = if volumes, do: "Stopping and removing", else: "Stopping"
    Mix.shell().info("#{action} services from #{file}...")

    compose_opts = [
      file: file,
      profiles: profiles,
      project_name: project_name,
      volumes: volumes
    ]

    case Compose.down(compose_opts) do
      :ok ->
        Mix.shell().info("Services stopped successfully!")

      {:error, output} ->
        Mix.shell().error("Failed to stop services:")
        Mix.shell().error(output)
        exit({:shutdown, 1})
    end
  end
end
