#include <cstdio>

int main() {
    long long a, b;
    if (std::scanf("%lld%lld", &a, &b) != 2) return 2;
    std::printf("%lld\n", a + b);
}
