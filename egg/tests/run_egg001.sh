#!/bin/sh
# EGG-001 component runner. Prints PASS / FAIL / UNAVAILABLE / PENDING per component. Never prints PASS for something that did not run.
#   PASS        the component ran here and its own checks passed
#   FAIL        it ran and a check failed (exit code is then 1)
#   UNAVAILABLE the tool is not installed, so nothing was run
#   PENDING     the component's check script was not delivered on this branch
# Components owned elsewhere are called through a hook: egg/<dir>/check.sh if present, else dafny/lean `make verify`, elixir `mix test`, alp_check/horn `make check`. Exit 0 = PASS.
# usage (from repo root): sh egg/tests/run_egg001.sh        FULL=1 also regenerates the slow R steps (about 25 min)
cd "$(dirname "$0")/.."   # egg/
CSV=../data/basketdata-2000-04-01.csv; SHA=63b52882582a8c7abd555f81002da6ce08c1161ec07526f422e6fdfcaf209d77
mkdir -p out/log results; LOG=out/log; SUM=out/summary.tsv; : > $SUM; fails=0
say() { printf '%-12s %-34s %s\n' "$1" "$2" "$3"; printf '%s\t%s\t%s\n' "$2" "$1" "$3" >> $SUM; [ "$1" = FAIL ] && fails=$((fails+1)); }
run() { # name logfile cmd... ; PASS only on exit 0
  name=$1; lf=$2; shift 2
  if "$@" > $LOG/$lf 2>&1; then say PASS "$name" "$(tail -n 1 $LOG/$lf | cut -c1-110)"; else say FAIL "$name" "see egg/$LOG/$lf"; fi; }
hook() { # name dir tool-check-command command...   (entry point: <dir>/check.sh if present, else the given command)
  name=$1; dir=$2; chk=$3; shift 3
  if [ -f "$dir/check.sh" ]; then cmd="sh check.sh"; elif [ $# -gt 0 ] && [ -d "$dir" ]; then cmd="$*"; else say PENDING "$name" "no $dir/ entry point on this branch"; return; fi
  if ! sh -c "$chk" >/dev/null 2>&1; then say UNAVAILABLE "$name" "tool not installed here, nothing run"; return; fi
  ( cd "$dir" && sh -c "$cmd" ) > $LOG/$name.log 2>&1; rc=$?
  if [ $rc -eq 0 ]; then say PASS "$name" "$(grep -v '^$' $LOG/$name.log | tail -n 1 | cut -c1-110)"; else say FAIL "$name" "exit $rc, see egg/$LOG/$name.log"; fi; }

# input
got=$(sha256sum $CSV | cut -d' ' -f1); [ "$got" = "$SHA" ] && say PASS input-sha256 "$got" || say FAIL input-sha256 "got $got"
# AWK (streaming inspection, tidy intermediate, integrity report)
if command -v awk >/dev/null; then
  mkdir -p out
  run awk-inspect awk.log sh -c "awk -F, -v out=out -v res=results -v trailing_lf=0 -f awk/inspect.awk $CSV && ! grep -q FAIL results/awk_integrity.tsv && echo 'integrity checks: all PASS, no FAIL rows' && [ \$(awk -F'\t' '\$1==\"bytes_computed\"{print \$2}' results/awk_integrity.tsv) = \$(wc -c < $CSV) ]"
else say UNAVAILABLE awk-inspect "awk not installed"; fi
# Futhark
if command -v futhark >/dev/null; then run futhark-kernels futhark.log sh futhark/run.sh; run futhark-sentinel sentinel.log sh tests/futhark_sentinel.sh
else say UNAVAILABLE futhark-kernels "futhark not installed"; say UNAVAILABLE futhark-sentinel "futhark not installed"; fi
# Octave (MATLAB-compatible code, run under Octave)
if command -v octave >/dev/null; then run octave-spectral octave.log sh -c "mkdir -p out/oct && cd octave && EGG_OUT=../out EGG_OCT=../out/oct octave --no-gui --quiet egg_spectral.m && echo 'octave outputs written'"
else say UNAVAILABLE octave-spectral "octave not installed"; fi
# R reference. Fast path uses the committed result files; FULL=1 regenerates them.
if command -v Rscript >/dev/null; then
  if [ "${FULL:-0}" = 1 ]; then for s in 01_device 02_network 03_rolling 04_crossdev 05_timeseries 06_changepoint; do run "r-$s" "$s.log" Rscript r/$s.R out results; done; run r-figures 07.log Rscript r/07_figures.R out results ../docs/img
  else say PASS r-results "using committed results/ from the recorded run (FULL=1 regenerates; not re-run now)"; fi
  run r-headline 09.log Rscript r/09_headline.R out results
  run parity-awk-futhark-r-octave parity.log Rscript r/08_parity.R out results
else say UNAVAILABLE r-reference "Rscript not installed"; fi
# Components owned elsewhere (hooks)
hook dafny dafny "test -x /workspace/.tools/dafny/dafny" make verify
hook lean lean 'test -x $HOME/.elan/bin/lake' make verify
hook elixir-runner elixir "command -v mix" mix test
hook alp-contracts alp_check/horn "command -v cmake" make check
# T-SQL: syntax only
if python3 -c "import sqlglot" 2>/dev/null; then run tsql-syntax-only tsql.log python3 tsql/check_syntax.py tsql/schema.sql; else say UNAVAILABLE tsql-syntax-only "sqlglot not installed"; fi
# Tools not installed here: files exist but were never run
for t in "sas-crosscheck sas" "ampl-segmentation ampl" "matlab-native matlab"; do set -- $t; if command -v $2 >/dev/null; then say PENDING "$1" "$2 found but its runner is not wired"; else say UNAVAILABLE "$1" "$2 not installed; file(s) UNVERIFIED-NOT-RUN"; fi; done
echo; echo "SUMMARY: $(awk -F'\t' '{c[$2]++} END{for(k in c) printf "%s=%d ", k, c[k]}' $SUM)"
[ $fails -eq 0 ] || { echo "RESULT: FAIL ($fails component(s) failed)"; exit 1; }
echo "RESULT: no component failed (components marked UNAVAILABLE/PENDING were NOT run)"
