#pragma once
#include "atom.hpp"
#include <string>
#include <vector>
namespace alp { struct Proof { Atom conclusion; std::string source; std::vector<Proof> premises; }; }
