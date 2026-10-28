#include "alp/graph/graphblas_backend.hpp"
#include <graphblas.hpp>
#include <stdexcept>
#include <memory>
namespace alp::graph {
std::vector<std::pair<std::size_t,std::size_t>> GraphBLASBackend::transitive_closure(const Graph&g)const{
    const size_t n=g.index().size(); if(n==0)return {};
    grb::Matrix<bool> A(n,n,n*n), R(n,n,n*n), U(n,n,n*n);
    std::vector<size_t>I,J;I.reserve(g.edges().size());J.reserve(g.edges().size());
    for(const auto&e:g.edges()){I.push_back(e.source);J.push_back(e.target);}
    std::unique_ptr<bool[]> values(new bool[I.size()]); for(size_t k=0;k<I.size();++k)values[k]=true;
    if(!I.empty()){
        const auto rc=grb::buildMatrixUnique(A,I.data(),J.data(),values.get(),I.size(),grb::SEQUENTIAL);
        if(rc!=grb::SUCCESS) throw std::runtime_error("ALP/GraphBLAS adjacency construction failed");
    }
    R=A;
    const grb::Semiring<
        grb::operators::logical_or<bool>,
        grb::operators::logical_and<bool>,
        grb::identities::logical_false,
        grb::identities::logical_true
    > boolean_ring;
    for(;;){
        U=R;
        const auto rc=grb::mxm(U,R,A,boolean_ring);
        if(rc!=grb::SUCCESS) throw std::runtime_error("ALP/GraphBLAS Boolean mxm failed");
        grb::wait(U);
        if(grb::nnz(U)==grb::nnz(R)){R=std::move(U);break;}
        R=std::move(U);
    }
    std::vector<std::pair<size_t,size_t>> out;out.reserve(grb::nnz(R));
    for(auto it=R.cbegin();it!=R.cend();++it)out.emplace_back(it.i(),it.j());
    return out;
}
}
