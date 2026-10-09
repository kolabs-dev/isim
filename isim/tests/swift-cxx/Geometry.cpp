#include "include/Geometry.h"
int geo::sumSquares(int n) { int s = 0; for (int i = 1; i <= n; i++) s += i * i; return s; }
geo::Names geo::splitWords(const std::string &text) {
    Names out; std::string w;
    for (char c : text) { if (c == ' ') { if (!w.empty()) out.push_back(w); w.clear(); } else w += c; }
    if (!w.empty()) out.push_back(w);
    return out;
}
