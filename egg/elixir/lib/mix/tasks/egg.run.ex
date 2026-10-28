defmodule Mix.Tasks.Egg.Run do
  @shortdoc "Run the EGG-001 pipeline verifier and write egg/out/elixir_manifest.json"
  @moduledoc """
      mix egg.run [--exec] [--root PATH] [--out PATH]

  Default is verify mode (reads committed results, checks SHA-256 / status columns).
  `--exec` also shells out to awk (re-derivation) and tests/futhark_sentinel.sh.
  Exit status 1 if any stage is not `pass` (fail closed).
  """
  use Mix.Task

  @impl true
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [exec: :boolean, root: :string, out: :string])
    Mix.Task.run("app.start")
    root = Path.expand(opts[:root] || "..")
    out = opts[:out] || Path.join(root, "out/elixir_manifest.json")

    {status, %{manifest: m, json: json}} =
      Egg.Runner.run_and_write(out, root: root, exec: opts[:exec] || false)

    Mix.shell().info("mode=#{m.mode} status=#{m.status}")

    for s <- m.stages,
        do:
          Mix.shell().info(
            "  #{s.index} #{s.id}: #{s.status}#{if s.error, do: " (#{s.error})", else: ""}"
          )

    Mix.shell().info(
      "manifest: #{out}\nmanifest sha256: " <>
        (:crypto.hash(:sha256, json) |> Base.encode16(case: :lower))
    )

    if status != :ok, do: exit({:shutdown, 1})
  end
end
