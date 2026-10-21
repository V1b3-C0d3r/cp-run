# cp-run 1.0

**Write C++. Run it. Catch the bug.** One zsh script turns a source file into a running program, checks sample answers and saves reproducible stress-test failures. GCC and Clang share the same commands; useful defaults keep routine work short. Compatible with macOS (ARM/Intel) and GNU/Linux (ARM). Runs perfectly on any platform or setup.

## Quick start

```sh
cp-run main.cpp                 # Compile and run
cp-run debug main.cpp           # Run with sanitizers and library checks
cp-run compile main.cpp         # Compile only; print the binary's absolute path
```

Omit `main.cpp` when it is the only local `.cpp` file. With several candidates, cp-run uses `main.cpp` or your saved fallback. The language standard defaults to the newest ISO C++ mode advertised by the selected compiler.

## From sample to counterexample

```sh
cp-run test                     # input.txt → program → compare with ans.txt
cp-run test=auto 2 5             # Rerun just cases 2 and 5 from a test bundle
cp-run stress main.cpp brute.cpp gen.cpp   # Compare against a trusted solution
cp-run main.cpp -tm              # Warm once, then report time/memory
cp-run main.cpp -tm --average=5   # Median time, maximum memory, one visible stdout
```

Failed checks show the input, actual output and expected answer with numbered differences. Stress failures include the seed, saved files and a replay command. Start with ordinary text files; learn independent test bundles only when you need them. [Testing examples →](docs/TESTING.md)

## Try optimization profiles

```sh
cp-run main.cpp --profile=pragma          # O3 and loop unrolling; keep the target ISA
cp-run main.cpp --profile=pragma-fast     # Aggressive floating-point optimizations
cp-run main.cpp --profile=pragma-native -tm # Also tune for this machine, when supported
```

Profiles adapt to GCC/Clang without changing your source. Measure your workload: stronger optimization is not always faster, and fast math can change answers. Native builds are for the compiling machine. [Profile details](docs/CLI.md#optimization-profiles) · [Runnable examples](examples/README.md#optimization-profiles)

## Install one file

Download `cp-run.zsh`, then:

```sh
mkdir -p ~/.local/bin
install -m 755 cp-run.zsh ~/.local/bin/cp-run
```

Add `export PATH="$HOME/.local/bin:$PATH"` to `~/.zshrc` if that directory is not already in `PATH`.

You need **zsh 5.9+** and **GCC or Clang**. Python 3.9+ runs settings, answer checking, measurements and limits; its support code is embedded, so there is no second project file to install. macOS ARM is the primary target. To use Apple's Clang, add `--compiler=clang++` or save that choice below.

```sh
cp-run --set-defaults            # Edit compiler, files, checks and profiles
rm ~/.local/bin/cp-run           # Uninstall, including its embedded preferences
```

Settings stay inside the installed script. Save them before an upgrade and restore them afterward:

```sh
cp-run --export-settings=cp-run-settings.json
cp-run --import-settings=cp-run-settings.json
```

No config file is loaded on ordinary launches. `cp-run -` reuses the last built source; `cp-run run -` reuses the last primary binary in the same workspace. Launch history is small, separate user data.

## Go further

- [CLI reference](docs/CLI.md): every command and option, argument passing, profiles, resource limits and settings.
- [Testing guide](docs/TESTING.md): complete file contents, independent cases, readable failures and stress testing.
- [Runnable examples](examples/README.md): file I/O, arguments, profiles, resource limits and every testing mode.
- [MIT license](LICENSE).

<sub>Vibe-coded with AI assistance; reviewed changes and reproducible tests remain part of the workflow.</sub>
