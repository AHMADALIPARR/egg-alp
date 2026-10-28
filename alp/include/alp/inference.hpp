#pragma once
#include "knowledge_base.hpp"
#include "proof.hpp"
#include <vector>
namespace alp {
class InferenceEngine {
    const KnowledgeBase& kb_;
    static bool contains(const std::vector<Atom>&, const Atom&);
    bool prove_positive(const Atom&, const std::vector<Atom>&) const;
    void derive_once(std::vector<Atom>&, std::vector<Proof>&) const;
public:
    explicit InferenceEngine(const KnowledgeBase& kb): kb_(kb) {}
    std::vector<Atom> fixed_point(const std::vector<Atom>& seed = {}) const;
    std::vector<Proof> derive(std::vector<Atom>& closure) const;
    bool query(const Atom&, const std::vector<Atom>& closure = {}) const;
};
}
