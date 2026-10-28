#include "alp/abduction.hpp"
#include "alp/unification.hpp"
#include <stdexcept>
namespace alp {
std::vector<Model> AbductiveSolver::solve(const Atom&goal)const{
    auto preds=kb_.abducibles();
    std::vector<Atom> candidates;
    for(const auto&p:preds) if(p.arity==0) candidates.push_back({p,{}});
    const size_t n=candidates.size(); if(n>20) throw std::runtime_error("abducible search space exceeds deterministic enumeration bound");
    std::vector<Model>out;
    for(size_t mask=0;mask<(size_t(1)<<n);++mask){
        Model m; m.facts=kb_.facts();m.constraints=kb_.constraints();
        for(size_t i=0;i<n;++i)if(mask&(size_t(1)<<i))m.abduced.push_back(candidates[i]);
        InferenceEngine e(kb_);auto closure=e.fixed_point(m.abduced);bool goal_ok=false;
        for(const auto&f:closure){Substitution s;if(Unifier::unify(goal,f,s)){goal_ok=true;break;}}
        if(!goal_ok)continue;
        m.violations=violations(kb_,m);m.valid=m.violations.empty();if(m.valid){m.derived=closure;m.proofs=e.derive(m.derived);out.push_back(std::move(m));}
    }
    return out;
}
}
