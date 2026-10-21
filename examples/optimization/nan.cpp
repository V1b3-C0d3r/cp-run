#include <cmath>
#include <cstdio>
#include <cstdlib>

// Passing "nan" deliberately violates fast math's finite-value assumption.
// Clang may warn about this even though the value arrives only at runtime.
// Keep this demonstration separate from the warning-clean integer workload.
int main(int argc, char** argv) {
    if (argc != 2) return 2;
    const double value = std::strtod(argv[1], nullptr);
    std::printf("isnan=%d\n", static_cast<int>(std::isnan(value)));
}
