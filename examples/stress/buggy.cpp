#include <iostream>

int main() {
    long long a, b;
    if (!(std::cin >> a >> b)) return 2;
    // Intentional wrong answer: stress testing must find this extra one.
    std::cout << a + b + 1 << '\n';
}
