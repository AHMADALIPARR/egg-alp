#include "alp/integrity.hpp"
#include "alp/inference.hpp"
#include "alp/unification.hpp"
namespace alp {
std::vector<Violation> violations(const KnowledgeBase&kb,const Model&m){
    InferenceEngine e(kb); auto closure=e.fixed_point(m.abduced); std::vector<Violation> v;
    for(const auto&c:kb.constraints()){
        std::vector<Substitution> states(1);
        for(const auto&l:c.body){
            std::vector<Substitution> next;
            for(const auto&s:states){
                Atom q=apply_substitution(l.atom,s);
                if(l.negated){ if(!e.query(q,closure)) next.push_back(s); }
                else { for(const auto&f:closure){Substitution u=s;if(Unifier::unify(q,f,u))next.push_back(u);} }
            }
            states.swap(next); if(states.empty())break;
        }
        if(!states.empty())v.push_back({c});
    }
    return v;
}
bool satisfies_constraints(const KnowledgeBase&kb,const Model&m){return violations(kb,m).empty();}
}
