#pragma once
#include "clause.hpp"
#include <set>
#include <vector>
namespace alp {
class KnowledgeBase {
    std::vector<Atom> facts_; std::vector<HornClause> rules_; std::vector<IntegrityConstraint> constraints_; std::set<Predicate, bool(*)(const Predicate&,const Predicate&)> abducibles_;
    static bool pred_less(const Predicate&, const Predicate&);
public:
    KnowledgeBase();
    void assert_fact(const Atom&); void add_rule(const HornClause&); void add_constraint(const IntegrityConstraint&); void add_abducible(const Predicate&);
    const std::vector<Atom>& facts() const; const std::vector<HornClause>& rules() const; const std::vector<IntegrityConstraint>& constraints() const;
    bool is_abducible(const Predicate&) const; std::vector<Predicate> abducibles() const;
};
}
