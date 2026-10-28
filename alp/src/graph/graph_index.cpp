#include "alp/graph/graph_index.hpp"
#include <stdexcept>
namespace alp::graph { std::size_t GraphIndex::intern(const std::string&s){auto[i,ok]=ids_.emplace(s,names_.size());if(ok)names_.push_back(s);return i->second;}std::size_t GraphIndex::size()const{return names_.size();}const std::string&GraphIndex::name(std::size_t i)const{return names_.at(i);}bool GraphIndex::contains(const std::string&s)const{return ids_.contains(s);}std::size_t GraphIndex::id(const std::string&s)const{auto i=ids_.find(s);if(i==ids_.end())throw std::out_of_range(s);return i->second;} }
