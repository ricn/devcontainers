defmodule Mix.Tasks.Devcontainers.Up do
  @moduledoc """
  Starts Docker Compose services.

  ## Usage

      mix devcontainers.up [options]

  ## Options

    * `--file` - Path to compose file (default: auto-detect)
    * `--profile` - Activate a profile (can be repeated)
    * `--project-name` - Set project name

  ## Examples

      mix devcontainers.up
      mix devcontainers.up --file docker-compose.yml
      mix devcontainers.up --profile dev --profile debug

  """
  @shortdoc "Starts Docker Compose services"

  use Mix.Task

  alias Devcontainers.Docker.Compose
  alias Devcontainers.Config

  @switches [
    file: :string,
    profile: :keep,
    project_name: :string
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: @switches)

    unless Compose.available?() do
      Mix.shell().error("Docker Compose is not available. Please install Docker.")
      exit({:shutdown, 1})
    end

    config = Config.read()
    file = Keyword.get(opts, :file) || config.compose_file

    unless file do
      Mix.shell().error("""
      No compose file found. Create one with:

          mix devcontainers.init --postgres

      Or specify a file:

          mix devcontainers.up --file docker-compose.yml
      """)

      exit({:shutdown, 1})
    end

    unless File.exists?(file) do
      Mix.shell().error("Compose file not found: #{file}")
      exit({:shutdown, 1})
    end

    profiles =
      opts
      |> Keyword.get_values(:profile)
      |> case do
        [] -> config.profiles
        p -> p
      end

    project_name = Keyword.get(opts, :project_name) || config.project_name

    Mix.shell().info("Starting services from #{file}...")

    compose_opts = [
      file: file,
      profiles: profiles,
      project_name: project_name,
      detach: true,
      wait: true
    ]

    case Compose.up(compose_opts) do
      :ok ->
        Mix.shell().info("Services started successfully!")
        show_status(file, profiles, project_name)

      {:error, output} ->
        Mix.shell().error("Failed to start services:")
        Mix.shell().error(output)
        exit({:shutdown, 1})
    end
  end

  defp show_status(file, profiles, project_name) do
    case Compose.ps(file: file, profiles: profiles, project_name: project_name) do
      {:ok, containers} ->
        Mix.shell().info("")
        Mix.shell().info("Running containers:")

        Enum.each(containers, fn container ->
          name = Map.get(container, "Name", "unknown")
          state = Map.get(container, "State", "unknown")
          ports = format_ports(Map.get(container, "Publishers", []))

          Mix.shell().info("  #{name} (#{state}) #{ports}")
        end)

      {:error, _} ->
        :ok
    end
  end

  defp format_ports([]), do: ""

  defp format_ports(publishers) do
    ports =
      publishers
      |> Enum.filter(fn p -> Map.get(p, "PublishedPort", 0) > 0 end)
      |> Enum.map(fn p ->
        "#{Map.get(p, "PublishedPort")}->#{Map.get(p, "TargetPort")}"
      end)
      |> Enum.join(", ")

    if ports == "", do: "", else: "[#{ports}]"
  end
end
