#pragma once
#include "term.hpp"
#include "predicate.hpp"
#include <string>
#include <vector>
namespace alp {
struct Atom { Predicate predicate; std::vector<Term> arguments; bool operator==(const Atom&) const = default; std::string to_string() const; };
std::string to_string(const Atom&);
bool structurally_equal(const Atom&, const Atom&);
}
