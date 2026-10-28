#pragma once
#include "graph.hpp"
#include <vector>
namespace alp::graph {
#ifdef ALP_GRAPHBLAS_ENABLED
class GraphBLASBackend {
public:
    std::vector<std::pair<std::size_t,std::size_t>> transitive_closure(const Graph&) const;
};
#else
class GraphBLASBackend { public: std::vector<std::pair<std::size_t,std::size_t>> transitive_closure(const Graph&) const = delete; };
#endif
}
