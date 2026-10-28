#include "alp/graph/bridge.hpp"
#include <cassert>
static bool has(const std::vector<std::pair<size_t,size_t>>&r,size_t a,size_t b){for(auto[x,y]:r)if(x==a&&y==b)return true;return false;}
int main(){
 alp::graph::Graph g;g.add_edge("a","b");g.add_edge("b","c");g.add_edge("c","d");g.add_edge("a","e");g.add_edge("e","f");
 auto r=alp::graph::Reachability().compute(g);
 assert(has(r,g.index().id("a"),g.index().id("d")));assert(has(r,g.index().id("a"),g.index().id("f")));assert(has(r,g.index().id("b"),g.index().id("d")));assert(!has(r,g.index().id("d"),g.index().id("a")));
 alp::graph::GraphPredicateBridge bridge;assert(bridge.supports({"reachable",2}));assert(bridge.query({{"reachable",2},{alp::Term::constant("a"),alp::Term::constant("d")}},g));assert(!bridge.query({{"reachable",2},{alp::Term::constant("d"),alp::Term::constant("a")}},g));
}
