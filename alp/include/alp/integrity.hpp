#pragma once
#include "model.hpp"
#include "knowledge_base.hpp"
namespace alp { bool satisfies_constraints(const KnowledgeBase&, const Model&); std::vector<Violation> violations(const KnowledgeBase&, const Model&); }
