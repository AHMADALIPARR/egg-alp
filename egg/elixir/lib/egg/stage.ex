defmodule Egg.Stage do
  @moduledoc """
  A pipeline stage definition (pure data, plus an optional `exec` function).

    * `id`       - stable atom/string identifier; also the ordering key's label
    * `outputs`  - paths (relative to the egg root) that MUST exist and be non-empty
    * `checks`   - list of content checks (see `Egg.Checks`)
    * `exec`     - optional `fn root, scratch -> {:ok, [check_result]} | {:error, reason} end`,
                   only run in `exec: true` mode (shells out to awk / futhark scripts)
  """
  @enforce_keys [:id]
  defstruct id: nil, outputs: [], checks: [], exec: nil
end
