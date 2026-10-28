defmodule Egg.Stage.Worker do
  @moduledoc """
  One worker process per stage, started under `Egg.StageSup` (restart: :temporary, so a
  crashing stage is isolated and never restarted behind the runner's back).
  The worker reports `{:stage_result, run_ref, stage_id, result}` to the runner and stops.
  The `run_ref` lets the runner discard stale results from earlier/abandoned runs.
  """
  use GenServer, restart: :temporary

  def start(args), do: DynamicSupervisor.start_child(Egg.StageSup, {__MODULE__, args})
  def start_link(args), do: GenServer.start_link(__MODULE__, args)

  @impl true
  def init(args), do: {:ok, args, {:continue, :run}}

  @impl true
  def handle_continue(:run, %{stage: stage, root: root, scratch: scratch, exec: exec?} = s) do
    result = Egg.Stage.Work.perform(stage, root, scratch, exec?)
    send(s.parent, {:stage_result, s.run_ref, stage.id, result})
    {:stop, :normal, s}
  end
end
