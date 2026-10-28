#pragma once
#include "term.hpp"
#include "atom.hpp"
#include <map>
namespace alp {
class Substitution {
    std::map<std::string, Term> bindings_;
public:
    bool bind(const std::string&, const Term&); bool contains(const std::string&) const;
    const Term* lookup(const std::string&) const; const std::map<std::string,Term>& bindings() const { return bindings_; }
};
Term apply_substitution(const Term&, const Substitution&);
Atom apply_substitution(const Atom&, const Substitution&);
Substitution compose_substitution(const Substitution&, const Substitution&);
}
