# Dafny contracts for EGG-001.  `make verify` runs dafny and logs to VERIFY.log.
# Dafny 4.11.0 (self-contained zip) lives under /workspace/.tools/dafny; needs dotnet 8 runtime.
DAFNY ?= /workspace/.tools/dafny/dafny
export DOTNET_ROOT ?= $(HOME)/.dotnet
export PATH := $(DOTNET_ROOT):$(PATH)

.PHONY: verify
verify:
	( $(DAFNY) --version; $(DAFNY) verify Nullable.dfy 2>&1; echo "dafny exit: $$?" ) | tee VERIFY.log
	@if grep -n 'assume\|{:axiom}\|{:verify false}' Nullable.dfy; then echo "ASSUMPTION FOUND" | tee -a VERIFY.log; exit 1; else echo "no assume/axiom/verify-false in Nullable.dfy" | tee -a VERIFY.log; fi
