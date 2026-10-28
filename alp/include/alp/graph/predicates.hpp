#pragma once
#include "graph.hpp"
#include "../atom.hpp"
#include <set>
namespace alp::graph {
class GraphPredicateRegistry { std::set<alp::Predicate> predicates_; public: GraphPredicateRegistry(); bool supports(const alp::Predicate&) const; std::set<alp::Predicate> predicates() const; };
std::vector<alp::Atom> materialize_reachable(const Graph&, const std::vector<std::pair<std::size_t,std::size_t>>&);
}
