#!/bin/bash
# Runs: (1) REAL facts must give 0 violations; (2) negative overlay must flag every EXPECT-IC id;
# (3) mutations of the REAL facts (sed) must each be flagged. Exit 0 only if all pass.
set -u
cd "$(dirname "$0")"
D=./build/check_driver; C=$(ls ../../contracts/horn/*.alp | sort); F=facts/egg001_facts.alp
echo "EGG-001 ALP contract check  (engine: alp/ unmodified; facts from egg/results/*.tsv via gen_facts.sh)"
echo "contracts: $(echo $C | tr '\n' ' ')"
fail=0
$D --label "REAL facts" $C $F --show status/2 --show test_executed/1 || fail=1
echo
$D --label "NEGATIVE overlay (must be flagged)" --expect-from negative/negative.alp $C $F negative/negative.alp --max-witness 1 > build/neg.out; rc=$?
grep -vE '^    ' build/neg.out | cut -c1-200; [ $rc -eq 0 ] || fail=1
echo
mkdir -p build
mut() { # name  sed-expr  expected-id
  sed -E "$2" $F > build/mut.alp
  if cmp -s $F build/mut.alp; then echo "MUTATION $1: sed changed nothing"; fail=1; return; fi
  $D --label "MUTATION $1" --expect "$3" $C build/mut.alp --max-witness 1 > build/mut.out; local rc=$?
  grep -E '^(==|VIOLATION|negative-test|  NOT|RESULT)' build/mut.out | cut -c1-200; [ $rc -eq 0 ] || fail=1
}
mut "device 1 first valid 1 s before the UTC day"  '0,/^dev_first_valid\(([^,]+),[0-9]+\)\./s//dev_first_valid(\1,946684799)./' dc_first_valid_outside_utc_day
mut "one audit check flipped pass->fail"           '0,/^check_status\(([^,]+),pass\)\./s//check_status(\1,fail)./' dc_audit_check_failed
mut "one histogram total off"                      '0,/^hist_total\(([^,]+),[0-9]+\)\./s//hist_total(\1,1)./' dc_histogram_total_mismatch
echo
if [ $fail -eq 0 ]; then echo "OVERALL: PASS (real facts clean; negative + mutation sets flagged)"; else echo "OVERALL: FAIL"; fi
exit $fail
