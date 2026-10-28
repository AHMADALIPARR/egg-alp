#pragma once
#include "atom.hpp"
#include <vector>
namespace alp {
struct Literal { Atom atom; bool negated{false}; };
struct HornClause { Atom head; std::vector<Literal> body; };
struct IntegrityConstraint { std::vector<Literal> body; };
}
