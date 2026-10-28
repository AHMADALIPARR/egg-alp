#pragma once
#include "graphblas_backend.hpp"
namespace alp::graph { class Reachability { GraphBLASBackend backend_; public: std::vector<std::pair<std::size_t,std::size_t>> compute(const Graph& g) const { return backend_.transitive_closure(g); } }; }
