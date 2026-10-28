#include "alp/parser.hpp"
#include "alp/abduction.hpp"
#include "alp/unification.hpp"
#include "alp/inference.hpp"
#include <cassert>
#include <iostream>
static alp::Atom a0(const std::string&s){return {{s,0},{}};}
int main(){
 {alp::Substitution s;auto x=alp::Term::variable("X");auto a=alp::Term::constant("alice");assert(alp::Unifier::unify(x,a,s));assert(alp::to_string(alp::apply_substitution(x,s))=="alice");}
 {auto p=alp::parse_program("edge(a,b). edge(b,c). reachable(X,Y) <- edge(X,Y). reachable(X,Z) <- edge(X,Y), reachable(Y,Z). ");alp::InferenceEngine e(p);auto c=e.fixed_point();assert(e.query({{"reachable",2},{alp::Term::constant("a"),alp::Term::constant("c")}},c));assert(!e.query({{"reachable",2},{alp::Term::constant("c"),alp::Term::constant("a")}},c));}
 {auto p=alp::parse_program("grass_is_wet. sun_is_shining. grass_is_wet <- rain. abducible(rain). false <- rain, sun_is_shining.");alp::Atom g{{"grass_is_wet",0},{}};auto ms=alp::AbductiveSolver(p).solve(g);assert(!ms.empty());}
 std::cout<<"ALP core tests passed\n";
#ifdef ALP_GRAPHBLAS_ENABLED
 std::cout<<"GraphBLAS integration tests require an ALP-enabled build.\n";
#endif
}
