// C++ used from Swift through C++ interoperability, including C++ standard library types (libc++ as Clang modules).
#pragma once
#include <map>
#include <optional>
#include <string>
#include <vector>

namespace geo {

struct Point {
    double x = 0, y = 0;
    Point() = default;
    Point(double x, double y) : x(x), y(y) {}
    double dot(const Point &o) const { return x * o.x + y * o.y; }
    Point operator+(const Point &o) const { return Point(x + o.x, y + o.y); }
    bool operator==(const Point &o) const { return x == o.x && y == o.y; }
};

class Accumulator {
public:
    explicit Accumulator(int start) : total_(start) {}
    void add(int v) { total_ += v; count_++; }
    int total() const { return total_; }
    int count() const { return count_; }
    static int twice(int v) { return 2 * v; }
private:
    int total_;
    int count_ = 0;
};

enum class Shape { circle, square };

template <typename T> T maxOf(T a, T b) { return a > b ? a : b; }
inline int maxInt(int a, int b) { return maxOf<int>(a, b); }

int sumSquares(int n);   // defined in Geometry.cpp

// the C++ standard library across the boundary (Swift names template specializations through typedefs)
using Names = std::vector<std::string>;
using Scores = std::map<std::string, int>;
using MaybeInt = std::optional<int>;
using Ints = std::vector<int>;
Names splitWords(const std::string &text);                  // Geometry.cpp
inline std::string joined(const Names &names, const std::string &sep) {
    std::string out;
    for (size_t i = 0; i < names.size(); i++) { if (i) out += sep; out += names[i]; }
    return out;
}
inline Scores lengths(const Names &names) { Scores m; for (auto &n : names) m[n] = (int)n.size(); return m; }
inline MaybeInt find(const Ints &v, int x) { for (size_t i = 0; i < v.size(); i++) if (v[i] == x) return (int)i; return std::nullopt; }
inline Ints squares(int n) { Ints v; for (int i = 1; i <= n; i++) v.push_back(i * i); return v; }

}  // namespace geo
