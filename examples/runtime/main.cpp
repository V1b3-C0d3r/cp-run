#include <chrono>
#include <iostream>
#include <string>
#include <thread>
#include <vector>

int main(int argc, char** argv) {
    unsigned long sleep_ms = 0, memory_mib = 0;
    std::string message = "done";
    try {
        for (int i = 1; i < argc; ++i) {
            const std::string arg = argv[i];
            if (arg.rfind("--sleep=", 0) == 0) sleep_ms = std::stoul(arg.substr(8));
            else if (arg.rfind("--memory=", 0) == 0) memory_mib = std::stoul(arg.substr(9));
            else if (arg.rfind("--echo=", 0) == 0) message = arg.substr(7);
            else return 2;
        }
    } catch (...) {
        return 2;
    }
    // Bound this demonstration: at most 120 ms of sleep and 64 MiB of storage.
    if (sleep_ms > 120 || memory_mib > 64) return 2;
    std::vector<unsigned char> storage(memory_mib * 1024 * 1024);
    volatile unsigned char* pages = storage.data();
    for (std::size_t i = 0; i < storage.size(); i += 4096) pages[i] = 1;
    std::this_thread::sleep_for(std::chrono::milliseconds(sleep_ms));
    std::cout << message << '\n';
}
