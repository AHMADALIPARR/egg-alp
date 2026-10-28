#include "alp/graph/graph.hpp"
namespace alp::graph { void Graph::add_edge(const std::string&a,const std::string&b){edges_.push_back({index_.intern(a),index_.intern(b)});}const GraphIndex&Graph::index()const{return index_;}const std::vector<Edge>&Graph::edges()const{return edges_;} }
