defmodule EggRunnerTest do
  use ExUnit.Case, async: false
  alias Egg.{Runner, Stage}

  setup do
    root = Path.join(System.tmp_dir!(), "egg_fixture_#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(root, "results"))
    File.mkdir_p!(Path.join(root, "data"))
    csv = "a,b\n1,2\n"
    File.write!(Path.join(root, "data/x.csv"), csv)
    sum = :crypto.hash(:sha256, csv) |> Base.encode16(case: :lower)
    File.write!(Path.join(root, "data/SHA256SUMS"), "#{sum}  x.csv\n")
    File.write!(Path.join(root, "results/one.tsv"), "k\tv\tstatus\na\t1\tPASS\n")
    File.write!(Path.join(root, "results/two.tsv"), "k\tv\n1\t2\n")
    on_exit(fn -> File.rm_rf!(root) end)

    stages = [
      %Stage{
        id: "data",
        outputs: ["data/x.csv", "data/SHA256SUMS"],
        checks: [{:sha256sums, "data/x.csv", "data/SHA256SUMS"}]
      },
      %Stage{
        id: "one",
        outputs: ["results/one.tsv"],
        checks: [{:tsv_no_fail, "results/one.tsv"}]
      },
      %Stage{
        id: "two",
        outputs: ["results/two.tsv"],
        checks: [{:min_lines, "results/two.tsv", 2}]
      }
    ]

    {:ok, root: root, stages: stages}
  end

  test "all stages pass and are reported in declared order", %{root: root, stages: stages} do
    assert {:ok, %{manifest: m}} = Runner.run(root: root, stages: stages)
    assert m.status == "pass"
    assert m.stage_order == ["data", "one", "two"]
    assert Enum.map(m.stages, & &1.index) == [0, 1, 2]
    [%{outputs: outs} | _] = m.stages
    assert Enum.all?(outs, &(byte_size(&1.sha256) == 64))
  end

  test "determinism: two runs give byte-identical manifests", %{root: root, stages: stages} do
    {:ok, a} = Runner.run(root: root, stages: stages)
    {:ok, b} = Runner.run(root: root, stages: stages)
    assert a.json == b.json
    p1 = Path.join(root, "m1.json")
    p2 = Path.join(root, "m2.json")
    Runner.run_and_write(p1, root: root, stages: stages)
    Runner.run_and_write(p2, root: root, stages: stages)
    assert File.read!(p1) == File.read!(p2)
  end

  test "output hash changes when content changes", %{root: root, stages: stages} do
    {:ok, a} = Runner.run(root: root, stages: stages)
    File.write!(Path.join(root, "results/two.tsv"), "k\tv\n1\t3\n")
    {:ok, b} = Runner.run(root: root, stages: stages)
    refute a.json == b.json
  end

  test "missing output => error, fail closed, later stages skipped", %{root: root, stages: stages} do
    File.rm!(Path.join(root, "results/one.tsv"))
    assert {:error, %{manifest: m}} = Runner.run(root: root, stages: stages)
    assert m.status == "fail"
    assert [%{status: "pass"}, %{status: "error", error: err}, %{status: "skipped"}] = m.stages
    assert err =~ "results/one.tsv (missing)"
  end

  test "empty output counts as missing", %{root: root, stages: stages} do
    File.write!(Path.join(root, "results/two.tsv"), "")

    assert {:error, %{manifest: %{stages: [_, _, %{status: "error", error: err}]}}} =
             Runner.run(root: root, stages: stages)

    assert err =~ "empty"
  end

  test "checksum mismatch fails the data stage and blocks the rest", %{root: root, stages: stages} do
    File.write!(Path.join(root, "data/x.csv"), "tampered\n")
    assert {:error, %{manifest: m}} = Runner.run(root: root, stages: stages)
    assert [%{status: "fail"}, %{status: "skipped"}, %{status: "skipped"}] = m.stages
  end

  test "a FAIL row in a status column fails the stage", %{root: root, stages: stages} do
    File.write!(Path.join(root, "results/one.tsv"), "k\tv\tstatus\na\t1\tFAIL\n")

    assert {:error, %{manifest: %{stages: [_, %{status: "fail"}, %{status: "skipped"}]}}} =
             Runner.run(root: root, stages: stages)
  end

  test "stale messages from another run are discarded", %{root: root, stages: stages} do
    {:ok, clean} = Runner.run(root: root, stages: stages)
    # stale results (old run ref, and a duplicate for a real stage id) already in the mailbox
    send(
      self(),
      {:stage_result, make_ref(), "one", %{status: "pass", error: nil, outputs: [], checks: []}}
    )

    send(
      self(),
      {:stage_result, make_ref(), "data",
       %{status: "fail", error: "stale", outputs: [], checks: []}}
    )

    {:ok, r} = Runner.run(root: root, stages: stages)
    assert r.json == clean.json
    assert Enum.count(r.audit, &match?({:discarded_stale, _}, &1)) == 2
  end

  @tag :capture_log
  test "a crashing worker is isolated: reported as error, supervisor survives", %{
    root: root,
    stages: stages
  } do
    boom = %Stage{id: "boom", exec: fn _, _ -> raise "kaboom" end}
    sup = Process.whereis(Egg.StageSup)

    {:error, %{manifest: m}} =
      Runner.run(root: root, stages: [hd(stages), boom, List.last(stages)], exec: true)

    assert [%{status: "pass"}, %{status: "error", error: err}, %{status: "skipped"}] = m.stages
    assert err =~ "kaboom"
    assert Process.whereis(Egg.StageSup) == sup
    assert {:ok, _} = Runner.run(root: root, stages: stages)
  end

  test "a hung worker times out and fails closed", %{root: root, stages: stages} do
    hang = %Stage{id: "hang", exec: fn _, _ -> Process.sleep(5_000) end}

    {:error, %{manifest: %{stages: [%{status: "error", error: err}, %{status: "skipped"}]}}} =
      Runner.run(root: root, stages: [hang, hd(stages)], exec: true, timeout: 100)

    assert err =~ "exceeded"
  end

  test "exec mode shells out and a non-zero command fails closed", %{root: root, stages: stages} do
    ok = %Stage{
      id: "sh_ok",
      exec: fn r, _ ->
        {out, 0} = System.cmd("sh", ["-c", "echo hi"], cd: r)
        {:ok, [Egg.Checks.result("echo", if(out == "hi\n", do: "pass", else: "fail"), "ran")]}
      end
    }

    bad = %Stage{
      id: "sh_bad",
      exec: fn r, _ ->
        case System.cmd("sh", ["-c", "exit 3"], cd: r) do
          {_, 0} -> {:ok, []}
          {_, c} -> {:error, "exit #{c}"}
        end
      end
    }

    assert {:ok, _} = Runner.run(root: root, stages: [ok], exec: true)

    assert {:error, %{manifest: %{stages: [%{status: "error", error: "exec failed: exit 3"}]}}} =
             Runner.run(root: root, stages: [bad], exec: true)

    # exec stages are not run in verify mode
    assert {:ok, _} = Runner.run(root: root, stages: [bad])
    assert hd(stages)
  end

  test "JSON encoder is deterministic and escapes" do
    assert Egg.Json.encode(%{b: 1, a: ["x\"y", nil]}) ==
             Egg.Json.encode(%{a: ["x\"y", nil], b: 1})

    assert Egg.Json.encode(%{a: "q\"\n"}) =~ ~S("q\"\n")
  end

  @tag :real
  test "real egg tree: verify twice gives identical manifest and is ordered" do
    root = Path.expand("..", __DIR__)

    if File.dir?(Path.join(root, "results")) do
      {s1, a} = Runner.run(root: root)
      {s2, b} = Runner.run(root: root)
      assert a.json == b.json
      assert s1 == s2
      assert a.manifest.stage_order == ~w(data_integrity awk futhark r octave parity)
    end
  end
end
