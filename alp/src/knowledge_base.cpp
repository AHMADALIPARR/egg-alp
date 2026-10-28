#include "alp/knowledge_base.hpp"
namespace alp {
bool KnowledgeBase::pred_less(const Predicate&a,const Predicate&b){return a.name<b.name || (a.name==b.name && a.arity<b.arity);}
KnowledgeBase::KnowledgeBase():abducibles_(&KnowledgeBase::pred_less){}
void KnowledgeBase::assert_fact(const Atom&a){facts_.push_back(a);} void KnowledgeBase::add_rule(const HornClause&r){rules_.push_back(r);} void KnowledgeBase::add_constraint(const IntegrityConstraint&c){constraints_.push_back(c);} void KnowledgeBase::add_abducible(const Predicate&p){abducibles_.insert(p);}
const std::vector<Atom>& KnowledgeBase::facts()const{return facts_;} const std::vector<HornClause>& KnowledgeBase::rules()const{return rules_;} const std::vector<IntegrityConstraint>& KnowledgeBase::constraints()const{return constraints_;}
bool KnowledgeBase::is_abducible(const Predicate&p)const{return abducibles_.contains(p);} std::vector<Predicate> KnowledgeBase::abducibles()const{return {abducibles_.begin(),abducibles_.end()};}
}
