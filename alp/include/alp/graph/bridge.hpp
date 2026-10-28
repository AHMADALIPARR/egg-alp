#pragma once
#include "graph.hpp"
#include "predicates.hpp"
#include "reachability.hpp"
#include "../atom.hpp"
#include <vector>
namespace alp::graph {
class GraphPredicateBridge {
    GraphPredicateRegistry registry_;
    Reachability reachability_;
public:
    bool supports(const alp::Predicate&) const;
    std::vector<alp::Atom> execute(const alp::Atom&, const Graph&) const;
    bool query(const alp::Atom&, const Graph&) const;
};
}
