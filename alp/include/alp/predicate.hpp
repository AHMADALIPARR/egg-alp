#pragma once
#include <string>
namespace alp { struct Predicate { std::string name; std::size_t arity{}; bool operator==(const Predicate&) const = default; }; }
