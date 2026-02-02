defmodule Devcontainers.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Devcontainers.Services.Registry,
      Devcontainers.Lifecycle.Manager
    ]

    opts = [strategy: :one_for_one, name: Devcontainers.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
