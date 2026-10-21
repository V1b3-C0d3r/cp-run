#include <cstdio>
#include <cstdlib>

int main(int argc, char** argv) {
    if (argc != 2) return 2;
    const auto seed = std::strtoull(argv[1], nullptr, 10);
    // Keep generated sums small; identical seeds produce identical bytes.
    std::printf("%llu %llu\n", seed % 100, (seed / 100) % 100 + 2);
}
