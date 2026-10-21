#include <iostream>
#include <limits>

int main() {
    volatile int largest = std::numeric_limits<int>::max();
    // Intentional undefined arithmetic: both debug profiles should stop here.
    const int overflow = largest + 1;
    std::cout << overflow << '\n';
}
