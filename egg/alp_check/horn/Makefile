# EGG-001 ALP contract check.  `make check` => regenerate facts, build driver, run the real + negative + mutation checks,
# save the output to CHECK.log.  Uses the UNMODIFIED alp/ engine (libalp_logic.a).
SHELL := /bin/bash
ROOT  := ../../..
ALPLIB:= $(ROOT)/build/libalp_logic.a
CON   := $(sort $(wildcard ../../contracts/horn/*.alp))
FACTS := facts/egg001_facts.alp
DRV   := build/check_driver

.PHONY: check facts engine clean
check: $(DRV) facts
	@set -o pipefail; ./run_checks.sh 2>&1 | tee CHECK.log

engine:
	cmake -S $(ROOT)/alp -B $(ROOT)/build -DALP_GRAPHBLAS_ENABLE=OFF >/dev/null
	cmake --build $(ROOT)/build -j --target alp_logic

$(ALPLIB):
	$(MAKE) engine

$(DRV): check_driver.cpp $(ALPLIB)
	@mkdir -p build
	g++ -std=c++20 -O2 -Wall -Wextra -I$(ROOT)/alp/include check_driver.cpp $(ALPLIB) -o $(DRV)

facts:
	@mkdir -p facts
	./gen_facts.sh > $(FACTS)

clean:
	rm -rf build facts/egg001_facts.alp CHECK.log
