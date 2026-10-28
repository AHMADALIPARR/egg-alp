#include "alp/term.hpp"
#include <sstream>
namespace alp {
Term Term::variable(std::string s){return {Variable{std::move(s)}};} Term Term::constant(std::string s){return {Constant{std::move(s)}};}
Term Term::compound(std::string f,std::vector<Term> a){std::vector<TermPtr> p; for(auto& x:a)p.push_back(clone_term(x)); return {Compound{std::move(f),std::move(p)}};}
bool Term::is_variable()const{return std::holds_alternative<Variable>(value);} bool Term::is_constant()const{return std::holds_alternative<Constant>(value);} bool Term::is_compound()const{return std::holds_alternative<Compound>(value);}
const Variable& Term::as_variable()const{return std::get<Variable>(value);} const Constant& Term::as_constant()const{return std::get<Constant>(value);} const Compound& Term::as_compound()const{return std::get<Compound>(value);}
TermPtr clone_term(const Term& t){return std::make_shared<Term>(t);} std::string to_string(const Term&t){if(t.is_variable())return t.as_variable().name;if(t.is_constant())return t.as_constant().name;std::ostringstream o;o<<t.as_compound().functor<<"(";for(size_t i=0;i<t.as_compound().arguments.size();++i){if(i)o<<",";o<<to_string(*t.as_compound().arguments[i]);}return o<<")",o.str();}
bool operator==(const Term&a,const Term&b){if(a.value.index()!=b.value.index())return false;if(a.is_variable())return a.as_variable()==b.as_variable();if(a.is_constant())return a.as_constant()==b.as_constant();auto&x=a.as_compound();auto&y=b.as_compound();if(x.functor!=y.functor||x.arguments.size()!=y.arguments.size())return false;for(size_t i=0;i<x.arguments.size();++i)if(!(*x.arguments[i]==*y.arguments[i]))return false;return true;}
}
