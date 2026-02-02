defmodule Mix.Tasks.Devcontainers.Status do
  @moduledoc """
  Shows the status of Docker Compose services.

  ## Usage

      mix devcontainers.status [options]

  ## Options

    * `--file` - Path to compose file (default: auto-detect)
    * `--profile` - Profile to use (can be repeated)
    * `--project-name` - Set project name

  ## Examples

      mix devcontainers.status
      mix devcontainers.status --file docker-compose.yml

  """
  @shortdoc "Shows Docker Compose service status"

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
      Mix.shell().error("Docker Compose is not available.")
      exit({:shutdown, 1})
    end

    config = Config.read()
    file = Keyword.get(opts, :file) || config.compose_file

    unless file do
      Mix.shell().error("No compose file found.")
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

    case Compose.ps(file: file, profiles: profiles, project_name: project_name) do
      {:ok, []} ->
        Mix.shell().info("No running containers for #{file}")

      {:ok, containers} ->
        Mix.shell().info("Services from #{file}:")
        Mix.shell().info("")

        Enum.each(containers, fn container ->
          print_container(container)
        end)

      {:error, output} ->
        Mix.shell().error("Failed to get status:")
        Mix.shell().error(output)
        exit({:shutdown, 1})
    end
  end

  defp print_container(container) do
    name = Map.get(container, "Name", "unknown")
    service = Map.get(container, "Service", "unknown")
    state = Map.get(container, "State", "unknown")
    status = Map.get(container, "Status", "")
    health = Map.get(container, "Health", "")

    state_color =
      case state do
        "running" -> :green
        "exited" -> :red
        _ -> :yellow
      end

    Mix.shell().info([
      "  ",
      :bright,
      service,
      :reset,
      " (#{name})"
    ])

    Mix.shell().info([
      "    State: ",
      state_color,
      state,
      :reset,
      if(status != "", do: " - #{status}", else: ""),
      if(health != "", do: " [#{health}]", else: "")
    ])

    publishers = Map.get(container, "Publishers", [])

    if length(publishers) > 0 do
      ports =
        publishers
        |> Enum.filter(fn p -> Map.get(p, "PublishedPort", 0) > 0 end)
        |> Enum.map(fn p ->
          published = Map.get(p, "PublishedPort")
          target = Map.get(p, "TargetPort")
          "#{published}->#{target}"
        end)

      if length(ports) > 0 do
        Mix.shell().info("    Ports: #{Enum.join(ports, ", ")}")
      end
    end

    Mix.shell().info("")
  end
end
