#!/bin/bash
# EGG-001 ALP contract check: build unmodified alp/ engine, regenerate facts from egg/results/*.tsv,
# run real facts (must be 0 violations) + negative overlay + mutations (must all be flagged).
# Exit nonzero on any failure. Output saved to egg/results/alp_check.txt (deterministic: no timestamps).
set -u
cd "$(dirname "$0")/../.." || exit 2
RES=egg/results/alp_check.txt
(
  echo "run.sh: cmake -S alp -B build -DALP_GRAPHBLAS_ENABLE=OFF && cmake --build build   (via horn/Makefile 'engine')"
  make -C egg/alp_check/horn -s engine >/tmp/alp_engine_build.log 2>&1 || { echo "run.sh: ENGINE BUILD FAILED"; cat /tmp/alp_engine_build.log; exit 2; }
  echo "run.sh: engine built: build/libalp_logic.a"
  echo "run.sh: make -C egg/alp_check/horn check"
  echo
  make -C egg/alp_check/horn -s check 2>&1
  exit ${PIPESTATUS[0]}
) > "$RES" 2>&1
rc=$?
cat "$RES"
[ $rc -eq 0 ] && grep -q '^OVERALL: PASS' "$RES" || { echo "run.sh: FAILED"; exit 1; }
echo "run.sh: exit 0"
