// EGG-001 ALP checker driver. Uses the unmodified alp_logic library (parser, InferenceEngine, integrity).
// Usage: check_driver [--label L] [--expect id,id,...] [--expect-from FILE] [--show pred/arity]... [--max-witness N] file.alp...
// Loads every file (concatenated in the given order), parses it as ONE program, computes the fixed point
// and evaluates every integrity constraint, printing each violated constraint with its witnesses.
// Constraint ids come from the "% IC <id>: <text>" comment line directly above each one-line "false <- ..." statement
// (the ALP parser discards comments, so the driver pairs them by order).
// Exit: 0 = no violations (or, with --expect*, every expected id was flagged); 1 = otherwise; 2 = usage/parse error.
#include "alp/parser.hpp"
#include "alp/inference.hpp"
#include "alp/integrity.hpp"
#include "alp/unification.hpp"
#include <algorithm>
#include <fstream>
#include <iostream>
#include <map>
#include <set>
#include <sstream>

static std::string lit_str(const alp::Literal& l) { return std::string(l.negated ? "not " : "") + l.atom.to_string(); }
static std::string trim(std::string s) { size_t a = s.find_first_not_of(" \t\r"); if (a == std::string::npos) return ""; size_t b = s.find_last_not_of(" \t\r"); return s.substr(a, b - a + 1); }
static std::vector<std::string> split(const std::string& s, char c) { std::vector<std::string> o; std::stringstream ss(s); std::string x; while (std::getline(ss, x, c)) if (!trim(x).empty()) o.push_back(trim(x)); return o; }

int main(int argc, char** argv) {
    std::string label = "run", expect_csv, expect_from; std::vector<std::string> files, shows; size_t max_w = 3;
    for (int i = 1; i < argc; ++i) {
        std::string a = argv[i];
        if (a == "--label" && i + 1 < argc) label = argv[++i];
        else if (a == "--expect" && i + 1 < argc) expect_csv = argv[++i];
        else if (a == "--expect-from" && i + 1 < argc) expect_from = argv[++i];
        else if (a == "--show" && i + 1 < argc) shows.push_back(argv[++i]);
        else if (a == "--max-witness" && i + 1 < argc) max_w = std::stoul(argv[++i]);
        else files.push_back(a);
    }
    if (files.empty()) { std::cerr << "usage: check_driver [--label L] [--expect ids] [--expect-from FILE] [--show p/n] files...\n"; return 2; }

    std::string text; std::vector<std::pair<std::string, std::string>> labels; std::string pending_id, pending_desc;
    std::set<std::string> expect;
    for (auto& e : split(expect_csv, ',')) expect.insert(e);
    for (auto& f : files) {
        std::ifstream in(f); if (!in) { std::cerr << "cannot open " << f << "\n"; return 2; }
        std::string line;
        while (std::getline(in, line)) {
            text += line + "\n"; std::string t = trim(line);
            if (t.rfind("% IC ", 0) == 0) { auto c = t.find(':'); pending_id = trim(t.substr(5, c == std::string::npos ? std::string::npos : c - 5)); pending_desc = c == std::string::npos ? "" : trim(t.substr(c + 1)); }
            else if (t.rfind("false <-", 0) == 0 || t.rfind("false<-", 0) == 0) { labels.push_back({pending_id.empty() ? "unlabelled" : pending_id, pending_desc}); pending_id.clear(); pending_desc.clear(); }
            if (f == expect_from && t.rfind("% EXPECT-IC:", 0) == 0) for (auto& e : split(t.substr(12), ' ')) expect.insert(e);
        }
    }
    if (!expect_from.empty() && std::find(files.begin(), files.end(), expect_from) == files.end()) {
        std::ifstream in(expect_from); std::string line; while (std::getline(in, line)) { std::string t = trim(line); if (t.rfind("% EXPECT-IC:", 0) == 0) for (auto& e : split(t.substr(12), ' ')) expect.insert(e); }
    }

    alp::KnowledgeBase kb;
    try { kb = alp::parse_program(text); } catch (const std::exception& e) { std::cerr << "PARSE ERROR: " << e.what() << "\n"; return 2; }
    if (kb.constraints().size() != labels.size()) { std::cerr << "LABEL MISMATCH: " << kb.constraints().size() << " constraints parsed, " << labels.size() << " 'false <-' lines\n"; return 2; }

    alp::InferenceEngine eng(kb); auto closure = eng.fixed_point({});
    std::cout << "== " << label << " ==\n";
    std::cout << "loaded: " << kb.facts().size() << " facts, " << kb.rules().size() << " rules, " << kb.constraints().size()
              << " integrity constraints; fixed point: " << closure.size() << " atoms (" << closure.size() - kb.facts().size() << " derived)\n";

    std::set<std::string> flagged; size_t total_w = 0;
    for (size_t ci = 0; ci < kb.constraints().size(); ++ci) {
        const auto& c = kb.constraints()[ci];
        std::vector<alp::Substitution> states(1);
        for (const auto& l : c.body) {
            std::vector<alp::Substitution> next;
            for (const auto& s : states) {
                alp::Atom q = alp::apply_substitution(l.atom, s);
                if (l.negated) { bool found = false; for (const auto& f : closure) { alp::Substitution u; if (alp::Unifier::unify(q, f, u)) { found = true; break; } } if (!found) next.push_back(s); }
                else for (const auto& f : closure) { alp::Substitution u = s; if (alp::Unifier::unify(q, f, u)) next.push_back(u); }
            }
            states.swap(next); if (states.empty()) break;
        }
        if (states.empty()) continue;
        flagged.insert(labels[ci].first); total_w += states.size();
        std::cout << "VIOLATION " << labels[ci].first << " [" << states.size() << " witness" << (states.size() == 1 ? "" : "es") << "]: " << labels[ci].second << "\n";
        std::string body; for (size_t i = 0; i < c.body.size(); ++i) body += (i ? ", " : "") + lit_str(c.body[i]);
        std::cout << "    rule: false <- " << body << "\n";
        for (size_t w = 0; w < states.size() && w < max_w; ++w) {
            std::string g; for (size_t i = 0; i < c.body.size(); ++i) { alp::Literal l = c.body[i]; l.atom = alp::apply_substitution(l.atom, states[w]); g += (i ? ", " : "") + lit_str(l); }
            std::cout << "    witness: " << g << "\n";
        }
        if (states.size() > max_w) std::cout << "    ... " << states.size() - max_w << " more\n";
    }
    std::cout << "constraints violated: " << flagged.size() << " distinct ids, " << total_w << " witnesses\n";

    for (auto& sh : shows) {
        auto sl = sh.find('/'); std::string name = sh.substr(0, sl); size_t ar = sl == std::string::npos ? 0 : std::stoul(sh.substr(sl + 1));
        std::vector<std::string> out; for (auto& a : closure) if (a.predicate.name == name && a.predicate.arity == ar) out.push_back(a.to_string());
        std::sort(out.begin(), out.end()); std::cout << "show " << sh << " (" << out.size() << "):";
        { for (auto& s : out) std::cout << " " << s; std::cout << "\n"; }
    }

    if (expect.empty()) {
        std::cout << (flagged.empty() ? "RESULT: PASS (0 violations)\n" : "RESULT: FAIL (violations above)\n");
        return flagged.empty() ? 0 : 1;
    }
    std::set<std::string> all; for (auto& l : labels) all.insert(l.first);
    std::vector<std::string> missed, unknown, hit; for (auto& e : expect) { if (!all.count(e)) unknown.push_back(e); else if (!flagged.count(e)) missed.push_back(e); else hit.push_back(e); }
    std::vector<std::string> unex; for (auto& l : all) if (!flagged.count(l)) unex.push_back(l);
    std::cout << "negative-test expectation: " << hit.size() << "/" << expect.size() << " expected constraints flagged\n";
    for (auto& e : missed) std::cout << "  NOT FLAGGED (check does not bite): " << e << "\n";
    for (auto& e : unknown) std::cout << "  UNKNOWN constraint id in EXPECT: " << e << "\n";
    std::cout << "coverage: " << flagged.size() << " of " << all.size() << " constraint ids flagged; not exercised by this set:";
    { for (auto& u : unex) std::cout << " " << u; std::cout << "\n"; }
    bool ok = missed.empty() && unknown.empty();
    std::cout << (ok ? "RESULT: PASS (negative set flagged as required)\n" : "RESULT: FAIL (negative set not fully flagged)\n");
    return ok ? 0 : 1;
}
