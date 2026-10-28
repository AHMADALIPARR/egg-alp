# EGG-001 top-level targets. Run from the repository root.
.PHONY: egg001 egg001-full egg001-manifest
egg001:        ## runs every component that is available here; prints PASS/FAIL/UNAVAILABLE/PENDING for each
	@sh egg/tests/run_egg001.sh
egg001-full:   ## same, and regenerates every slow R step first (about 25 minutes)
	@FULL=1 sh egg/tests/run_egg001.sh
egg001-manifest: ## writes egg/results/manifest.json (run after egg001)
	@cd egg && Rscript r/11_manifest.R out results
