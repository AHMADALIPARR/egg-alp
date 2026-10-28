#pragma once
#include "graph.hpp"
namespace alp::graph { class AdjacencyMatrix { public: AdjacencyMatrix(); explicit AdjacencyMatrix(const Graph&); void rebuild(const Graph&); std::size_t size() const; const Graph& graph() const; private: Graph graph_; }; }
