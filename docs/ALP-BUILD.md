# Building and testing the ALP code

The ALP code lives in `alp/`, unchanged from the archive it came in. It builds and passes its tests without any change to the source.

## Without ALP/GraphBLAS (what was run)

```sh
cmake -S alp -B build -DALP_GRAPHBLAS_ENABLE=OFF
cmake --build build
ctest --test-dir build --output-on-failure
```

Result on 2026-10-27 (Linux, GCC 14.2.0, CMake):

- Configure and build: succeeded with no errors. Built `libalp_logic.a`, `alp_demo` and `alp_tests`.
- `ctest`: `1/1 Test #1: alp_tests ... Passed`, "100% tests passed, 0 tests failed out of 1".
- `./build/alp_tests` prints `ALP core tests passed`.
- `./build/alp_demo` runs and prints `valid ALP models: 5`.

This covers the logic layer: parser, unification, inference, abduction, integrity constraints.

## With ALP/GraphBLAS (not run)

The graph backend needs ALP installed and `-DALP_ROOT=/path/to/ALP -DALP_GRAPHBLAS_ENABLE=ON`. ALP is not installed on the machine this repo was assembled on, so `tests/graphblas_test.cpp` and the graph backend have not been built or run.

## Not part of the research runtime

The EGG-001 spec says the analysis runtime has no AI, agents or language models. The ALP code has no connection to the dataset yet. It is here as the logic engine; nothing in this repo feeds EGG data into it.
