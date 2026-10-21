#include <cstdio>
#include <vector>

// This integer-only workload is valid with every optimization profile,
// including fast math and warnings promoted to errors. See nan.cpp for the
// separate floating-point example, which deliberately violates fast math.
int main() {
    constexpr unsigned n = 4096;
    std::vector<unsigned> input(n), output(n);
    for (unsigned i = 0; i < n; ++i) input[i] = (i * 17u + 13u) % 1009u;
    for (unsigned i = 0; i < n; ++i) output[i] = input[i] + input[i];
    unsigned long long checksum = 0;
    for (unsigned value : output) checksum += value;
    std::printf("checksum=%llu\n", checksum);
}
