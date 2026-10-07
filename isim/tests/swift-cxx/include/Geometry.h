// C++ used from Swift through C++ interoperability (no C++ standard library types: isim's libc++ headers do not
// build as a Clang module yet, so std::string / std::vector are not importable).
#pragma once

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

}  // namespace geo
