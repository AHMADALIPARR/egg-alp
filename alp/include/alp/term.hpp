#pragma once
#include <memory>
#include <string>
#include <variant>
#include <vector>
namespace alp {
struct Term;
using TermPtr = std::shared_ptr<const Term>;
struct Variable { std::string name; bool operator==(const Variable&) const = default; };
struct Constant { std::string name; bool operator==(const Constant&) const = default; };
struct Compound { std::string functor; std::vector<TermPtr> arguments; };
struct Term {
    std::variant<Variable, Constant, Compound> value;
    static Term variable(std::string); static Term constant(std::string);
    static Term compound(std::string, std::vector<Term>);
    bool is_variable() const; bool is_constant() const; bool is_compound() const;
    const Variable& as_variable() const; const Constant& as_constant() const; const Compound& as_compound() const;
};
TermPtr clone_term(const Term&);
std::string to_string(const Term&);
bool operator==(const Term&, const Term&);
}
