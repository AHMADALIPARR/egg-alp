#pragma once
#include "inference.hpp"
#include "integrity.hpp"
namespace alp {
class AbductiveSolver {
    const KnowledgeBase& kb_;
public:
    explicit AbductiveSolver(const KnowledgeBase& kb): kb_(kb) {}
    std::vector<Model> solve(const Atom& goal) const;
};
}
