#include "alp/graph/adjacency.hpp"
namespace alp::graph { AdjacencyMatrix::AdjacencyMatrix()=default;AdjacencyMatrix::AdjacencyMatrix(const Graph&g):graph_(g){}void AdjacencyMatrix::rebuild(const Graph&g){graph_=g;}std::size_t AdjacencyMatrix::size()const{return graph_.index().size();}const Graph&AdjacencyMatrix::graph()const{return graph_;} }
