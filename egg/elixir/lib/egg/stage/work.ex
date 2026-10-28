defmodule Egg.Stage.Work do
  @moduledoc "The pure(ish) body of a stage: exec (optional), output presence, hashes, checks."
  alias Egg.Checks

  def perform(stage, root, scratch, exec?) do
    {exec_checks, exec_err} =
      cond do
        exec? and is_function(stage.exec, 2) ->
          case stage.exec.(root, scratch) do
            {:ok, checks} -> {checks, nil}
            {:error, reason} -> {[], reason}
          end

        true ->
          {[], nil}
      end

    outputs =
      for rel <- Enum.sort(stage.outputs) do
        path = Path.join(root, rel)

        case File.stat(path) do
          {:ok, %{type: :regular, size: size}} when size > 0 ->
            %{path: rel, bytes: size, sha256: Checks.sha256_file(path), present: true}

          {:ok, %{type: :regular}} ->
            %{path: rel, bytes: 0, sha256: nil, present: false, problem: "empty"}

          _ ->
            %{path: rel, bytes: nil, sha256: nil, present: false, problem: "missing"}
        end
      end

    missing = for %{present: false, path: p, problem: why} <- outputs, do: "#{p} (#{why})"
    content = if missing == [], do: Enum.map(stage.checks, &Checks.run(root, &1)), else: []
    all_checks = exec_checks ++ content

    cond do
      exec_err != nil ->
        %{status: "error", error: "exec failed: #{exec_err}", outputs: outputs, checks: []}

      missing != [] ->
        %{
          status: "error",
          error: "missing output: " <> Enum.join(missing, ", "),
          outputs: outputs,
          checks: []
        }

      Enum.any?(all_checks, &(&1.status != "pass")) ->
        %{status: "fail", error: nil, outputs: outputs, checks: all_checks}

      true ->
        %{status: "pass", error: nil, outputs: outputs, checks: all_checks}
    end
  end
end
