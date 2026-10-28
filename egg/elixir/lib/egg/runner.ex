defmodule Egg.Runner do
  @moduledoc """
  Deterministic pipeline runner.

  Stages run strictly one after another, in list order, each in its own supervised worker
  (`Egg.Stage.Worker` under `Egg.StageSup`). Fail closed: the first stage that is not `pass`
  (fail / error / crashed / timeout) stops the run; later stages are recorded as `skipped`
  and the overall status is `fail`. Messages carry a per-run reference; anything that does
  not match the current run+stage (stale/late/duplicate) is discarded (and audited).

  The manifest contains no timestamps, PIDs or refs, so two runs over identical files give
  byte-identical JSON.
  """
  alias Egg.Json

  @type opts :: [
          root: Path.t(),
          stages: [Egg.Stage.t()],
          exec: boolean(),
          timeout: pos_integer(),
          scratch: Path.t()
        ]

  @doc "Runs the pipeline. Returns `{:ok | :error, %{manifest: map, json: binary, audit: [term]}}`."
  def run(opts \\ []) do
    root = opts |> Keyword.get(:root, ".") |> Path.expand()
    stages = Keyword.get(opts, :stages, Egg.Pipeline.stages())
    exec? = Keyword.get(opts, :exec, false)
    timeout = Keyword.get(opts, :timeout, 600_000)
    scratch = Keyword.get(opts, :scratch, Path.join(root, "out/elixir_scratch"))

    {results, audit, _halted} =
      stages
      |> Enum.with_index()
      |> Enum.reduce({[], [], false}, fn {stage, idx}, {acc, audit, halted} ->
        if halted do
          {[skipped(stage, idx) | acc], [{:skipped, stage.id} | audit], true}
        else
          {res, audit} = run_stage(stage, idx, root, scratch, exec?, timeout, audit)
          {[res | acc], audit, res.status != "pass"}
        end
      end)

    results = Enum.reverse(results)
    ok? = Enum.all?(results, &(&1.status == "pass"))

    manifest = %{
      schema: "egg-001-elixir-manifest/1",
      experiment: "EGG-001",
      runner: "Egg.Runner (deterministic; no LLM, no agents, no sampling)",
      mode: if(exec?, do: "exec", else: "verify"),
      status: if(ok?, do: "pass", else: "fail"),
      fail_closed: true,
      stage_order: Enum.map(results, & &1.id),
      stages: results,
      runtime: %{elixir: System.version(), otp: System.otp_release()}
    }

    {if(ok?, do: :ok, else: :error),
     %{manifest: manifest, json: Json.encode(manifest), audit: Enum.reverse(audit)}}
  end

  @doc "Run and write the manifest JSON to `path`."
  def run_and_write(path, opts \\ []) do
    {status, %{json: json} = r} = run(opts)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, json)
    {status, r}
  end

  defp run_stage(stage, idx, root, scratch, exec?, timeout, audit) do
    run_ref = make_ref()

    args = %{
      stage: stage,
      root: root,
      scratch: scratch,
      exec: exec?,
      parent: self(),
      run_ref: run_ref
    }

    case Egg.Stage.Worker.start(args) do
      {:ok, pid} ->
        mon = Process.monitor(pid)
        {outcome, audit} = await(run_ref, stage.id, mon, pid, timeout, audit)
        Process.demonitor(mon, [:flush])
        {finish(stage, idx, outcome), [{:stage_done, stage.id} | audit]}

      {:error, reason} ->
        {finish(stage, idx, {:crashed, "could not start worker: #{inspect(reason)}"}), audit}
    end
  end

  defp await(ref, id, mon, pid, timeout, audit) do
    receive do
      {:stage_result, ^ref, ^id, result} ->
        {{:ok, result}, audit}

      {:stage_result, _other_ref, other_id, _} ->
        # stale: result of an earlier / abandoned run or another stage; discard.
        await(ref, id, mon, pid, timeout, [{:discarded_stale, other_id} | audit])

      {:DOWN, ^mon, :process, ^pid, :normal} ->
        # worker exited normally; its result message is already in our mailbox if it was sent
        receive do
          {:stage_result, ^ref, ^id, result} -> {{:ok, result}, audit}
        after
          0 -> {{:crashed, "worker exited without result"}, audit}
        end

      {:DOWN, ^mon, :process, ^pid, reason} ->
        {{:crashed, "worker crashed: " <> reason_text(reason)}, audit}
    after
      timeout ->
        DynamicSupervisor.terminate_child(Egg.StageSup, pid)
        {{:timeout, "stage exceeded #{timeout} ms"}, audit}
    end
  end

  defp finish(stage, idx, {:ok, r}),
    do: base(stage, idx, r.status) |> Map.merge(Map.take(r, [:error, :outputs, :checks]))

  defp finish(stage, idx, {:crashed, msg}),
    do: base(stage, idx, "error") |> Map.merge(%{error: msg, outputs: [], checks: []})

  defp finish(stage, idx, {:timeout, msg}),
    do: base(stage, idx, "error") |> Map.merge(%{error: msg, outputs: [], checks: []})

  defp skipped(stage, idx),
    do:
      base(stage, idx, "skipped")
      |> Map.merge(%{error: "not run: an earlier stage did not pass", outputs: [], checks: []})

  defp base(stage, idx, status), do: %{index: idx, id: stage.id, status: status}

  defp reason_text({%{__exception__: true} = e, _st}), do: Exception.message(e)
  defp reason_text(other), do: inspect(other)
end
