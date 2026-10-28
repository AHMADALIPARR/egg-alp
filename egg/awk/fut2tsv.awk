# EGG-001 component: AWK. Convert ONE Futhark text-format output value (one input line)
# into TSV: a 1-D array becomes one column; a 2-D array becomes rows. Type suffixes
# (i64, f64, ...) are stripped; NaN stays as the text NA (never as 0).
{
  s = $0
  gsub(/(i|u)(8|16|32|64)/, "", s); gsub(/f(32|64)/, "", s)
  gsub(/NaN/, "NA", s); gsub(/ /, "", s)
  if (substr(s, 1, 2) == "[[") {
    s = substr(s, 2, length(s) - 2)
    n = split(s, rows, /\],\[/)
    for (i = 1; i <= n; i++) { r = rows[i]; gsub(/[\[\]]/, "", r); gsub(/,/, "\t", r); print r }
  } else if (substr(s, 1, 1) == "[") {
    s = substr(s, 2, length(s) - 2)
    n = split(s, a, ",")
    for (i = 1; i <= n; i++) print a[i]
  } else print s
}
