defmodule Egg.Application do
  @moduledoc """
  OTP application: a one_for_one Supervisor owning a DynamicSupervisor under which
  every pipeline stage runs as an isolated, temporary worker process.

  This is a deterministic experiment runner, not an AI agent layer: there is no LLM,
  no sampling and no randomness anywhere in it.
  """
  use Application

  @impl true
  def start(_type, _args) do
    children = [{DynamicSupervisor, name: Egg.StageSup, strategy: :one_for_one}]
    Supervisor.start_link(children, strategy: :one_for_one, name: Egg.Supervisor)
  end
end
