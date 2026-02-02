defmodule Devcontainers.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/yourusername/devcontainers"

  def project do
    [
      app: :devcontainers,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test
      ],
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:mix]
      ],

      # Hex
      description: "Spring Boot-style Docker Compose integration for Elixir applications",
      package: package(),

      # Docs
      name: "Devcontainers",
      docs: docs(),
      source_url: @source_url,
      homepage_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Devcontainers.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Required
      {:yaml_elixir, "~> 2.9"},
      {:jason, "~> 1.4"},

      # Optional
      {:req, "~> 0.4", optional: true},

      # Dev/Test only
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:mox, "~> 1.1", only: :test}
    ]
  end

  defp package do
    [
      maintainers: ["Your Name"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      },
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "guides/getting-started.md",
        "guides/configuration.md",
        "guides/custom-services.md",
        "guides/phoenix-integration.md"
      ],
      groups_for_extras: [
        Guides: ~r/guides\/.*/
      ],
      groups_for_modules: [
        "Docker Integration": [
          Devcontainers.Docker.Compose,
          Devcontainers.Docker.ComposeFile,
          Devcontainers.Docker.HealthCheck
        ],
        Services: [
          Devcontainers.Services.Service,
          Devcontainers.Services.Registry,
          Devcontainers.Services.ConnectionDetails,
          Devcontainers.Services.Postgres,
          Devcontainers.Services.MySQL,
          Devcontainers.Services.Redis,
          Devcontainers.Services.RabbitMQ,
          Devcontainers.Services.Kafka,
          Devcontainers.Services.MongoDB,
          Devcontainers.Services.Elasticsearch
        ],
        Lifecycle: [
          Devcontainers.Lifecycle.Manager
        ]
      ],
      source_ref: "v#{@version}"
    ]
  end
end
