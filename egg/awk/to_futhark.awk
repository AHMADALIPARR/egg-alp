# EGG-001 component: AWK -> Futhark text-format bridge.
#   awk -F'\t' -v mode=valsmask|mask [-v garbage=N] -f to_futhark.awk dense.tsv > fut_in.txt
# dense.tsv: empty cell = missing. Emits  vals : [t][d]i32  (missing -> -1, or `garbage`
# if given, only for the test that proves masked cells are never read)  and  mask : [t][d]bool.
BEGIN { if (garbage == "") miss = -1; else miss = garbage + 0 }
NR == 1 { nd = NF - 1; next }
{
  n++
  vrow = "["; mrow = "["
  for (j = 2; j <= NF; j++) {
    if ($j == "") { v = miss; m = "false" } else { v = $j; m = "true" }
    vrow = vrow (j > 2 ? "," : "") v "i32"
    mrow = mrow (j > 2 ? "," : "") m
  }
  V[n] = vrow "]"; M[n] = mrow "]"
}
END {
  if (mode == "valsmask") {
    printf "["; for (i = 1; i <= n; i++) printf "%s%s", (i > 1 ? "," : ""), V[i]; print "]"
  }
  printf "["; for (i = 1; i <= n; i++) printf "%s%s", (i > 1 ? "," : ""), M[i]; print "]"
}
