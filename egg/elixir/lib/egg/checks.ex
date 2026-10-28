defmodule Egg.Checks do
  @moduledoc "Pure, deterministic content checks. Each returns a map with name/status/detail."

  @doc "SHA-256 (lowercase hex) of a file, streamed."
  def sha256_file(path) do
    path
    |> File.stream!(65_536, [])
    |> Enum.reduce(:crypto.hash_init(:sha256), &:crypto.hash_update(&2, &1))
    |> :crypto.hash_final()
    |> Base.encode16(case: :lower)
  end

  def run(root, {:sha256sums, file, sums}) do
    name = "sha256sums:#{file}"

    with {:ok, text} <- File.read(Path.join(root, sums)),
         {:ok, want} <- find_sum(text, Path.basename(file)),
         true <- File.regular?(Path.join(root, file)) do
      got = sha256_file(Path.join(root, file))

      if got == want,
        do: result(name, "pass", "sha256 matches #{sums}"),
        else: result(name, "fail", "sha256 mismatch: expected #{want}, got #{got}")
    else
      false -> result(name, "fail", "file missing")
      {:error, reason} -> result(name, "fail", "cannot verify: #{inspect(reason)}")
    end
  end

  # No row may have status FAIL in the column headed "status".
  def run(root, {:tsv_no_fail, file}) do
    name = "tsv_no_fail:#{file}"

    case File.read(Path.join(root, file)) do
      {:ok, text} ->
        [header | rows] = String.split(text, "\n", trim: true)
        cols = String.split(header, "\t")

        case Enum.find_index(cols, &(&1 == "status")) do
          nil ->
            result(name, "fail", "no status column")

          i ->
            statuses = Enum.map(rows, fn r -> Enum.at(String.split(r, "\t"), i) end)
            fails = Enum.count(statuses, &(&1 == "FAIL"))
            passes = Enum.count(statuses, &(&1 == "PASS"))

            if fails == 0 and rows != [],
              do: result(name, "pass", "#{passes} PASS, 0 FAIL, #{length(rows)} rows"),
              else: result(name, "fail", "#{fails} FAIL of #{length(rows)} rows")
        end

      {:error, reason} ->
        result(name, "fail", "cannot read: #{inspect(reason)}")
    end
  end

  def run(root, {:min_lines, file, n}) do
    name = "min_lines:#{file}>=#{n}"

    case File.read(Path.join(root, file)) do
      {:ok, text} ->
        lines = length(String.split(text, "\n", trim: true))

        if lines >= n,
          do: result(name, "pass", "#{lines} lines"),
          else: result(name, "fail", "#{lines} lines < #{n}")

      {:error, reason} ->
        result(name, "fail", "cannot read: #{inspect(reason)}")
    end
  end

  def result(name, status, detail), do: %{name: name, status: status, detail: detail}

  defp find_sum(text, base) do
    text
    |> String.split("\n", trim: true)
    |> Enum.find_value({:error, :no_entry}, fn line ->
      case String.split(line, ~r/\s+/, parts: 2) do
        [sum, file] -> if String.trim_leading(file, "*") == base, do: {:ok, sum}, else: nil
        _ -> nil
      end
    end)
  end
end
