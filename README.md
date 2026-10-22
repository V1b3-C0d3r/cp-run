# cp-run

**From source to a checked answer in one command.** Compile C++ or C, run Python or PyPy, check samples, and find smaller counterexamples — with one installable script.

```sh
cp-run main.cpp                       # Build and run
cp-run debug main.cpp                 # Sanitizers and library assertions
cp-run compile main.cpp               # Build without running
```

C and Python work the same way:

```sh
cp-run main.c --compiler=clang
cp-run main.py --interpreter=pypy3
cp-run test                           # Discover source; use input.txt + ans.txt
cp-run stress                         # Discover main, brute and gen
cp-run main.cpp -tm --average=5        # One visible stdout; median time, peak RSS
```

No project configuration is required. Optional settings live inside the script and can be exported/imported.

## Install

Download `cp-run.zsh` from the [latest release](https://github.com/V1b3-C0d3r/cp-run/releases/latest), then:

```sh
mkdir -p ~/.local/bin
install -m 755 cp-run.zsh ~/.local/bin/cp-run
```

Add `~/.local/bin` to PATH if needed. Remove `~/.local/bin/cp-run` to uninstall. Dependencies are feature-specific: zsh 5.9+, a C/C++ compiler for native sources, a Python interpreter for Python sources. Tests, measurements, settings and integrations also need Python 3.9+ for the embedded standard-library services.

### macOS

Install [Apple Command Line Tools](https://developer.apple.com/xcode/resources/) with `xcode-select --install` for Apple Clang. With [Homebrew](https://docs.brew.sh/Installation):

```sh
brew install zsh python gcc
```

Select Apple Clang with `--compiler=clang`; GNU GCC is the native default. Package availability depends on macOS/architecture, especially Intel Macs. For Python/PyPy, select the actual installed interpreter executable.

### Debian / Ubuntu

```sh
sudo apt update
sudo apt install zsh build-essential clang python3
```

Check `zsh --version`; use a supported distribution with zsh 5.9+. Optional packages: `pypy3`, `clang-format`, `clang-tidy`. [PyPy downloads](https://pypy.org/download.html) cover additional platforms.

### Windows

Use [WSL2 with Ubuntu or Debian](https://learn.microsoft.com/en-us/windows/wsl/install), then follow the Linux instructions inside WSL. Native Windows is not supported. Browser-to-WSL Companion forwarding depends on the WSL networking setup.

### Optional tools

- **Formatting:** [clang-format](https://clang.llvm.org/docs/ClangFormat.html) for C/C++; [Ruff](https://docs.astral.sh/ruff/installation/) for Python. Black can be selected in defaults.
- **Further diagnostics:** [clang-tidy](https://clang.llvm.org/extra/clang-tidy/) and [Ruff check](https://docs.astral.sh/ruff/linter/) are useful separate tools; formatting does not enable automatic lint fixes.
- **Browser samples:** [Competitive Companion](https://github.com/jmerle/competitive-companion#installation). Add custom port **27122**, run `cp-run companion main.cpp`, then click the extension on one problem.

Run `cp-run --doctor` to see which tools are available. Nothing is installed automatically.

## Check your answer

Put one complete input in `input.txt` and its expected stdout in `ans.txt`:

```sh
cp-run test main.cpp --cout
```

For numbered samples, use `tests/1.in`, `tests/1.ans`, `tests/2.in`, `tests/2.ans`:

```sh
cp-run test=mult main.cpp --cout
```

Every test shows numbered input, actual output and answer, marked differences, a verdict, time and peak memory. Independent tests keep running after failures. The default report file is `test_out`; raw first-run output is `real-out.txt`.

Stress compares your solution with a reference on generated input:

```sh
cp-run stress main.cpp brute.py gen.py --test-iters=100
cp-run stress main.cpp brute.py gen.py --minimize=sequence --stop-on-failure
```

Failures preserve seeds, exact input/output and replay metadata. Sequence reduction repairs counts and keeps a confirmed wrong answer; add a validator for problem-specific constraints. [Test formats and complete examples](docs/TESTING.md).

## Debugging and control

`debug` uses native sanitizers and assertions from the **actual selected C++ library**. `debug=extra` adds stricter warnings/checks. Python profiles use interpreter diagnostics; they do not pretend to provide native sanitizers. `pragma`, `pragma-fast` and `pragma-native` are native optimization flag profiles with explicit unknown-pragma warnings; fast-math changes floating-point semantics.

```sh
cp-run debug=extra main.cpp
cp-run main.py -f=in data.txt -- -- --verbose
cp-run main.cpp --profile=pragma-native
cp-run --make-prettier                 # Format discovered source only
cp-run main.cpp --make-prettier        # Format, then build/run
cp-run --set-defaults                  # Edit tools, profiles, routing and limits
```

See [CLI](docs/CLI.md) for argument boundaries, priorities and exact contracts. [Examples](examples/README.md) contain small runnable projects.

## Build from modules

From a cloned repository, edit `development/src/`, then:

```sh
python3 -B development/build.py
python3 -B -m unittest discover -s development/tests -v
python3 -B development/package.py
```

The build generates **`cp-run.zsh`**; packaging creates **`cp-run-1.1.zip`**. Users install only the script; source modules and a Python package installation are unnecessary. [Development rules](docs/DEVELOPMENT.md).

MIT licensed. Contributions and reproducible bug reports are welcome.

<sub>Built with AI assistance; reviewed through regression tests and real toolchain runs.</sub>
