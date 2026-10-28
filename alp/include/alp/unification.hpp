#pragma once
#include "substitution.hpp"
namespace alp {
class Unifier {
public:
    static bool unify(const Term&, const Term&, Substitution&);
    static bool unify(const Atom&, const Atom&, Substitution&);
private:
    static bool occurs_check(const std::string&, const Term&, const Substitution&);
};
}
