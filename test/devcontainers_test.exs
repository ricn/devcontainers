defmodule DevcontainersTest do
  use ExUnit.Case
  doctest Devcontainers

  describe "enabled?/0" do
    test "returns true when enabled in config" do
      Application.put_env(:devcontainers, :enabled, true)
      assert Devcontainers.enabled?() == true
    after
      Application.delete_env(:devcontainers, :enabled)
    end

    test "returns false when disabled via environment variable" do
      System.put_env("DEVCONTAINERS_SKIP", "true")
      assert Devcontainers.enabled?() == false
    after
      System.delete_env("DEVCONTAINERS_SKIP")
    end
  end
end
