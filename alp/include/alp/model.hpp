#pragma once
#include "atom.hpp"
#include "clause.hpp"
#include "proof.hpp"
#include <vector>
namespace alp {
struct AbductiveHypothesis { Atom atom; };
struct Violation { IntegrityConstraint constraint; };
struct Model { std::vector<Atom> facts, derived, abduced; std::vector<IntegrityConstraint> constraints; std::vector<Proof> proofs; std::vector<Violation> violations; bool valid{true}; };
}
