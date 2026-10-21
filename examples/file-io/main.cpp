#include <cstdio>
#include <iostream>

int main() {
#ifdef FILEO
    // Bare -f defines FILEO with factory settings. The program owns these files.
    if (!std::freopen("input.txt", "r", stdin)) return 1;
    if (!std::freopen("output.txt", "w", stdout)) return 1;
#endif
    long long a, b;
    if (!(std::cin >> a >> b)) return 2;
    std::cout << a + b << '\n';
}
