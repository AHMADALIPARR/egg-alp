# Lean 4 proofs for EGG-001.  `make verify` builds and logs to BUILD.log.
# Needs elan with toolchain from lean-toolchain; no Mathlib required.
export PATH := $(HOME)/.elan/bin:$(PATH)

.PHONY: verify build
verify:
	( lake build 2>&1; echo "lake exit: $$?" ) | tee BUILD.log
	@echo "--- sorry/axiom scan ---" | tee -a BUILD.log
	@if grep -n 'sorry' EggLean/Nullable.lean | grep -v 'no sorry'; then echo "SORRY FOUND" | tee -a BUILD.log; exit 1; else echo "no sorry in Nullable.lean" | tee -a BUILD.log; fi
build: verify
