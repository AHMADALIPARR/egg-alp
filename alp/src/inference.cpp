#include "alp/inference.hpp"
#include "alp/unification.hpp"
namespace alp {
bool InferenceEngine::contains(const std::vector<Atom>&v,const Atom&a){for(auto&x:v)if(x==a)return true;return false;}
void InferenceEngine::derive_once(std::vector<Atom>&closure,std::vector<Proof>&proofs)const{std::vector<Atom>add;for(const auto&r:kb_.rules()){std::vector<Substitution> subs(1);for(const auto&lit:r.body){if(lit.negated){std::vector<Substitution> keep;for(auto&s:subs){Atom q=apply_substitution(lit.atom,s);if(!prove_positive(q,closure))keep.push_back(s);}subs.swap(keep);continue;}std::vector<Substitution> next;for(auto&s:subs)for(auto&f:closure){Substitution u=s;if(Unifier::unify(apply_substitution(lit.atom,s),f,u))next.push_back(u);}subs.swap(next);if(subs.empty())break;}for(auto&s:subs){Atom h=apply_substitution(r.head,s);if(!contains(closure,h)&&!contains(add,h)){add.push_back(h);proofs.push_back({h,"horn-clause",{}});}}}closure.insert(closure.end(),add.begin(),add.end());}
std::vector<Atom> InferenceEngine::fixed_point(const std::vector<Atom>&seed)const{std::vector<Atom>c=kb_.facts();for(auto&a:seed)if(!contains(c,a))c.push_back(a);while(true){auto before=c.size();std::vector<Proof>p;derive_once(c,p);if(c.size()==before)break;}return c;}
std::vector<Proof> InferenceEngine::derive(std::vector<Atom>&closure)const{std::vector<Proof>p;size_t before=0;while(before!=closure.size()){before=closure.size();derive_once(closure,p);}return p;}
bool InferenceEngine::prove_positive(const Atom&q,const std::vector<Atom>&closure)const{for(auto&f:closure){Substitution s;if(Unifier::unify(q,f,s))return true;}return false;}
bool InferenceEngine::query(const Atom&q,const std::vector<Atom>&seed)const{return prove_positive(q,fixed_point(seed));}
}
