defmodule Egg.Json do
  @moduledoc "Tiny deterministic JSON encoder: object keys sorted, fixed 2-space indentation."

  def encode(term), do: enc(term, 0) <> "\n"

  defp enc(nil, _), do: "null"
  defp enc(true, _), do: "true"
  defp enc(false, _), do: "false"
  defp enc(n, _) when is_integer(n), do: Integer.to_string(n)
  defp enc(a, _) when is_atom(a), do: str(Atom.to_string(a))
  defp enc(s, _) when is_binary(s), do: str(s)
  defp enc([], _), do: "[]"
  defp enc(%{} = m, _) when map_size(m) == 0, do: "{}"

  defp enc(list, d) when is_list(list) do
    pad = String.duplicate("  ", d + 1)
    items = Enum.map_join(list, ",\n", &(pad <> enc(&1, d + 1)))
    "[\n" <> items <> "\n" <> String.duplicate("  ", d) <> "]"
  end

  defp enc(%{} = m, d) do
    pad = String.duplicate("  ", d + 1)

    items =
      m
      |> Enum.map(fn {k, v} -> {to_string(k), v} end)
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map_join(",\n", fn {k, v} -> pad <> str(k) <> ": " <> enc(v, d + 1) end)

    "{\n" <> items <> "\n" <> String.duplicate("  ", d) <> "}"
  end

  defp str(s) do
    body =
      for <<c::utf8 <- s>>, into: "" do
        case c do
          ?" -> "\\\""
          ?\\ -> "\\\\"
          ?\n -> "\\n"
          ?\r -> "\\r"
          ?\t -> "\\t"
          c when c < 0x20 -> "\\u" <> String.pad_leading(Integer.to_string(c, 16), 4, "0")
          c -> <<c::utf8>>
        end
      end

    "\"" <> body <> "\""
  end
end
