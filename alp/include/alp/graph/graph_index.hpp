#pragma once
#include <cstddef>
#include <string>
#include <unordered_map>
#include <vector>
namespace alp::graph {
class GraphIndex { std::unordered_map<std::string,std::size_t> ids_; std::vector<std::string> names_;
public: std::size_t intern(const std::string&); std::size_t size() const; const std::string& name(std::size_t) const; bool contains(const std::string&) const; std::size_t id(const std::string&) const; };
}
