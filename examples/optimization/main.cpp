#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <vector>

int main(int argc, char** argv) {
    constexpr unsigned n = 4096;
    std::vector<unsigned> input(n), output(n);
    for (unsigned i = 0; i < n; ++i) input[i] = (i * 17u + 13u) % 1009u;
    for (unsigned i = 0; i < n; ++i) output[i] = input[i] + input[i];
    unsigned long long checksum = 0;
    for (unsigned value : output) checksum += value;
    std::printf("checksum=%llu\n", checksum);

    // Passing "nan" demonstrates why fast math is an explicit choice.
    if (argc == 2) {
        const double value = std::strtod(argv[1], nullptr);
        std::printf("isnan=%d\n", static_cast<int>(std::isnan(value)));
    }
}
