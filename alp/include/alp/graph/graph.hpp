#pragma once
#include "graph_index.hpp"
#include "../atom.hpp"
#include <vector>
namespace alp::graph { struct Edge { std::size_t source{}, target{}; }; class Graph { GraphIndex index_; std::vector<Edge> edges_;
public: void add_edge(const std::string&,const std::string&); const GraphIndex& index() const; const std::vector<Edge>& edges() const; }; }
