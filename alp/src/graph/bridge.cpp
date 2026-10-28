#include "alp/graph/bridge.hpp"
#include "alp/unification.hpp"
namespace alp::graph {
bool GraphPredicateBridge::supports(const alp::Predicate&p)const{return registry_.supports(p);}
std::vector<alp::Atom> GraphPredicateBridge::execute(const alp::Atom&q,const Graph&g)const{
    if(q.predicate==alp::Predicate{"reachable",2}){
        return materialize_reachable(g,reachability_.compute(g));
    }
    if(q.predicate==alp::Predicate{"edge",2}){
        std::vector<alp::Atom> out; for(const auto&e:g.edges())out.push_back({{"edge",2},{alp::Term::constant(g.index().name(e.source)),alp::Term::constant(g.index().name(e.target))}}); return out;
    }
    if(q.predicate==alp::Predicate{"node",1}){
        std::vector<alp::Atom> out; for(size_t i=0;i<g.index().size();++i)out.push_back({{"node",1},{alp::Term::constant(g.index().name(i))}}); return out;
    }
    return {};
}
bool GraphPredicateBridge::query(const alp::Atom&q,const Graph&g)const{for(const auto&a:execute(q,g)){alp::Substitution s;if(alp::Unifier::unify(q,a,s))return true;}return false;}
}
