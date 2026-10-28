defmodule Egg.Pipeline do
  @moduledoc """
  The EGG-001 stage list, in its fixed order:

      data_integrity -> awk -> futhark -> r -> octave -> parity

  Default (verify) mode only READS the committed results / intermediates and verifies them.
  `exec: true` additionally shells out: AWK re-derivation into a scratch dir (compared
  byte-for-byte against egg/results) and `tests/futhark_sentinel.sh` against the built binary.
  R and Octave are never re-run by the runner (R scripts rewrite the committed results);
  their committed outputs are hashed and checked.
  """
  alias Egg.{Checks, Stage}

  @data "../data/basketdata-2000-04-01.csv"
  @sums "../data/SHA256SUMS"

  @awk_results ~w(awk_device.tsv awk_hist.tsv awk_integrity.tsv awk_rowvalid.tsv)

  @r_results ~w(r_acf_followup_quarters r_acf_network r_acf_summary r_binomial_pmf r_corr_matrix
    r_crossdev_bootstrap_ci r_crossdev_global r_crossdev_lag_global r_crossdev_lag_profile
    r_crossdev_tail_global r_device_quantiles r_device_summary r_device_tails r_network_z_minute
    r_network_z_summary r_pair_crossdev r_periodogram_not_analysed r_periodogram_peaks
    r_periodogram_summary r_pooled_counts r_pooled_gof r_rolling_device r_rolling_global
    r_rolling_network r_rolling_network_series r_welch_peaks r_welch_psd r_welch_summary)

  @fut_outputs ~w(device_moments network_z network_z_calibrated cov corr simnull_device simnull_z)

  @oct_outputs ~w(oct_acf_network oct_corr5 oct_device_moments oct_network_z_head
    oct_network_z_summary oct_periodogram oct_roll60_dev1_var oct_welch)

  def stages do
    [
      %Stage{
        id: "data_integrity",
        outputs: [@data, @sums],
        checks: [{:sha256sums, @data, @sums}]
      },
      %Stage{
        id: "awk",
        outputs: Enum.map(@awk_results, &"results/#{&1}") ++ ["out/dense.tsv"],
        checks: [
          {:tsv_no_fail, "results/awk_integrity.tsv"},
          {:min_lines, "out/dense.tsv", 86_000}
        ],
        exec: &awk_rederive/2
      },
      %Stage{
        id: "futhark",
        outputs: Enum.map(@fut_outputs, &"out/fut/#{&1}.tsv"),
        checks: [{:min_lines, "out/fut/device_moments.tsv", 26}],
        exec: &futhark_sentinel/2
      },
      %Stage{
        id: "r",
        outputs: Enum.map(@r_results, &"results/#{&1}.tsv"),
        checks: [{:min_lines, "results/r_device_summary.tsv", 26}]
      },
      %Stage{
        id: "octave",
        outputs: Enum.map(@oct_outputs, &"out/oct/#{&1}.tsv"),
        checks: [{:min_lines, "out/oct/oct_device_moments.tsv", 2}]
      },
      %Stage{
        id: "parity",
        outputs: ["results/parity.tsv"],
        checks: [{:tsv_no_fail, "results/parity.tsv"}]
      }
    ]
  end

  # Re-run inspect.awk into a scratch dir and compare with committed results (read-only on egg/results).
  defp awk_rederive(root, scratch) do
    dir = Path.join(scratch, "awk")
    File.rm_rf!(dir)
    File.mkdir_p!(dir)
    data = Path.expand(@data, root)
    trailing = if last_byte(data) == "\n", do: "1", else: "0"

    {out, code} =
      System.cmd(
        "awk",
        [
          "-F,",
          "-v",
          "out=#{dir}",
          "-v",
          "res=#{dir}",
          "-v",
          "trailing_lf=#{trailing}",
          "-f",
          "awk/inspect.awk",
          data
        ],
        cd: root,
        stderr_to_stdout: true
      )

    if code != 0 do
      {:error, "awk exit #{code}: #{String.slice(out, 0, 200)}"}
    else
      pairs =
        Enum.map(@awk_results, &{"#{dir}/#{&1}", "results/#{&1}"}) ++
          [{"#{dir}/dense.tsv", "out/dense.tsv"}]

      {:ok,
       for {fresh, committed} <- pairs do
         same =
           File.regular?(fresh) and
             Checks.sha256_file(fresh) == Checks.sha256_file(Path.join(root, committed))

         Checks.result(
           "awk_rederive:#{committed}",
           if(same, do: "pass", else: "fail"),
           if(same, do: "fresh awk run byte-identical", else: "fresh awk run differs")
         )
       end}
    end
  end

  defp futhark_sentinel(root, _scratch) do
    if File.regular?(Path.join(root, "out/egg_fut")) do
      {out, code} =
        System.cmd("sh", ["tests/futhark_sentinel.sh"], cd: root, stderr_to_stdout: true)

      lines = String.split(out, "\n", trim: true)
      p = Enum.count(lines, &String.starts_with?(&1, "PASS"))
      f = Enum.count(lines, &String.starts_with?(&1, "FAIL"))

      {:ok,
       [
         Checks.result(
           "futhark_sentinel.sh",
           if(code == 0 and f == 0 and p > 0, do: "pass", else: "fail"),
           "exit #{code}, #{p} PASS, #{f} FAIL"
         )
       ]}
    else
      {:error, "out/egg_fut binary missing (run futhark/run.sh)"}
    end
  end

  defp last_byte(path) do
    {:ok, %{size: size}} = File.stat(path)

    File.open!(path, [:read, :binary], fn f ->
      {:ok, _} = :file.position(f, size - 1)
      IO.binread(f, 1)
    end)
  end
end
