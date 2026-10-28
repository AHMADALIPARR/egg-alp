# ALP/GraphBLAS Horn-Clause Runtime

Production-oriented C++ runtime for Horn-clause logic, abductive hypotheses, integrity constraints, negation as failure, and graph predicates lowered to the real ALP/GraphBLAS API.

## Dependency

This repository targets **ALP/GraphBLAS**, not a replacement implementation. ALP's public API is C++ and exposes `grb::Matrix`, sparse iterators, `buildMatrixUnique`, custom semirings, and `grb::mxm`.

Configure with an ALP source/install root:

```sh
cmake -S . -B build -DALP_ROOT=/path/to/ALP -DALP_GRAPHBLAS_ENABLE=ON
cmake --build build -j
ctest --test-dir build --output-on-failure
```

The logic layer can be built without ALP for isolated parser/unification/inference tests:

```sh
cmake -S . -B build -DALP_GRAPHBLAS_ENABLE=OFF
cmake --build build -j
ctest --test-dir build --output-on-failure
```

## Semantics

`P`, `A`, and `IC` are separate runtime collections. Horn rules derive facts; abducibles are hypotheses considered by the abductive solver; integrity constraints reject candidate models. Negation-as-failure is implemented as failure to establish a positive literal under the engine's fixed-point semantics and is not represented as classical negation.

The graph bridge recognizes `node/1`, `edge/2`, `connected/2`, `reachable/2`, and `path/2`. GraphBLAS results are materialized back as logical `reachable/2` atoms.

## GraphBLAS backend

The backend uses the actual ALP/GraphBLAS C++ API. Boolean graph algebra is expressed with a Boolean semiring: OR as addition and AND as multiplication. Transitive closure is iterated to a fixed point.

No LLM, probabilistic inference, embeddings, RAG, or proprietary graph algebra is used.

## Bridge boundary

`GraphPredicateBridge` is the explicit boundary between graph execution and logical atoms. It does not rewrite the source Horn program. The bridge executes supported graph predicates, then materializes results as `reachable/2`, `edge/2`, or `node/1` atoms for ordinary unification and logic evaluation.
