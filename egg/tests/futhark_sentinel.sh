#!/bin/sh
# Futhark nullable-array tests: (1) outputs must not depend on the value stored in a masked-out cell;
# (2) fixed-seed simulation must be bit-identical on repeat and differ for another seed.
# usage: tests/futhark_sentinel.sh  (from egg/, after futhark/run.sh)
set -u
cd "$(dirname "$0")/.."
O=out; T=$O/sentinel; mkdir -p $T; fail=0
[ -x $O/egg_fut ] || { echo "UNAVAILABLE futhark binary missing"; exit 2; }
awk -F'\t' -v mode=valsmask -v garbage=77 -f awk/to_futhark.awk $O/dense.tsv > $T/vm_garbage.txt
for e in device_moments network_z pairwise_cov_corr; do
  $O/egg_fut -e $e < $O/fut_vm.txt | sha256sum | cut -d' ' -f1 > $T/a.$e
  $O/egg_fut -e $e < $T/vm_garbage.txt | sha256sum | cut -d' ' -f1 > $T/b.$e
  if cmp -s $T/a.$e $T/b.$e; then echo "PASS sentinel-invariance $e (missing cells hold -1 vs 77: identical output)"; else echo "FAIL sentinel-invariance $e"; fail=1; fi
done
( cat $O/fut_vm.txt; echo 60i64 ) | $O/egg_fut -e rolling_moments | sha256sum > $T/a.r
( cat $T/vm_garbage.txt; echo 60i64 ) | $O/egg_fut -e rolling_moments | sha256sum > $T/b.r
if cmp -s $T/a.r $T/b.r; then echo "PASS sentinel-invariance rolling_moments"; else echo "FAIL sentinel-invariance rolling_moments"; fail=1; fi
h() { ( cat $O/fut_m.txt; echo "${1}i64" ) | $O/egg_fut -e sim_null | sha256sum | cut -d' ' -f1; }
a=$(h 20000401); b=$(h 20000401); c=$(h 20000402)
[ "$a" = "$b" ] && echo "PASS determinism sim_null seed 20000401 repeated: identical sha256 ${a%????????????????????????????????????????????????}" || { echo "FAIL determinism"; fail=1; }
[ "$a" != "$c" ] && echo "PASS seed sensitivity: seed 20000402 gives different output" || { echo "FAIL seed sensitivity"; fail=1; }
exit $fail
