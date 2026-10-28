#include "alp/parser.hpp"
#include "alp/abduction.hpp"
#include <iostream>
#ifdef ALP_GRAPHBLAS_ENABLED
#include "alp/graph/graph.hpp"
#include "alp/graph/reachability.hpp"
#include "alp/graph/predicates.hpp"
#endif
int main(){
 const std::string src=R"(% ALP example
gras_is_wet.
sun_is_shining.
grass_is_wet <- sprinkler_was_on.
grass_is_wet <- it_rained_last_night.
sprinkler_was_on <- sprinkler_broken, not it_rained_last_night.
pipes_froze <- cold_last_night.
sprinkler_was_on <- pipes_not_frozen, sprinkler_turned_on.
pipes_not_frozen <- not pipes_frozen.
sprinkler_turned_on <- not sprinkler_off.
abducible(it_rained_last_night).
abducible(sprinkler_broken).
abducible(cold_last_night).
abducible(sprinkler_off).
abducible(sprinkler_turned_on).
false <- it_rained_last_night, sun_is_shining.
false <- cold_last_night, sun_is_shining.
false <- sprinkler_was_on, it_rained_last_night.
false <- sprinkler_turned_on, sprinkler_off.
)";
 auto kb=alp::parse_program(src);alp::Atom goal{{"grass_is_wet",0},{}};auto models=alp::AbductiveSolver(kb).solve(goal);std::cout<<"valid ALP models: "<<models.size()<<"\n";if(!models.empty()){std::cout<<"abduced:";for(auto&a:models.front().abduced)std::cout<<" "<<a.to_string();std::cout<<"\n";}
#ifdef ALP_GRAPHBLAS_ENABLED
 alp::graph::Graph g;g.add_edge("a","b");g.add_edge("b","c");g.add_edge("c","d");g.add_edge("a","e");g.add_edge("e","f");auto r=alp::graph::Reachability().compute(g);auto facts=alp::graph::materialize_reachable(g,r);std::cout<<"reachable facts: "<<facts.size()<<"\n";
#endif
}
