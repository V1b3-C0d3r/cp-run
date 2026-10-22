# cp-run

**Your terminal, ready for competitive programming.**

Compile **C++ or C**, run **Python with PyPy or CPython**, check samples, and turn stress-test failures into smaller counterexamples. One installable script for macOS and Linux, with the editor you already use.

[![Tests](https://github.com/V1b3-C0d3r/cp-run/actions/workflows/ci.yml/badge.svg)](https://github.com/V1b3-C0d3r/cp-run/actions/workflows/ci.yml)

## Quick start

Open a directory containing your solution — `main.cpp`, `main.c` or `main.py` — and use:

```sh
cp-run                         # Find the source, compile if needed, and run
cp-run debug                   # Build with diagnostics; do not run
cp-run debug run               # Build with diagnostics, then run
cp-run compile                 # Prepare the program without running it
cp-run test --cout             # Check in.txt against ans.txt
cp-run stress --test-iters=100  # Find main, brute and gen; compare 100 generated tests
```

**No project setup is required.** C++ is preferred when several languages are present. A single supported source is discovered automatically; explicit filenames always work: `cp-run solution.cpp`.

- **See the failing lines.** Reports show numbered input, actual output and expected output, with differences marked.
- **Reproduce the bug.** Stress saves the seed, exact files and a replay command.
- **Measure each test.** Independent samples have their own time, memory and limits. Repeated measurements show stdout once.

[Install](#install) · [Samples](#check-samples) · [Counterexamples](#find-a-smaller-counterexample) · [Formatting](#format-your-source) · [Full CLI](docs/CLI.md) · [Examples](examples/README.md)

## Install

Download **`cp-run.zsh`** from the [latest release](https://github.com/V1b3-C0d3r/cp-run/releases/latest), then:

```sh
mkdir -p ~/.local/bin
install -m 755 cp-run.zsh ~/.local/bin/cp-run
export PATH="$HOME/.local/bin:$PATH"
```

Keep the PATH line in your shell's startup file (for example `~/.zshrc`). To uninstall, remove `~/.local/bin/cp-run`.

**Requirements:** zsh **5.9+**; GCC or Clang for C/C++; **PyPy 3** for Python by default, or a selected CPython interpreter. Measurements, tests, settings and integrations also use a separate **Python 3.9+** standard-library service. Run `cp-run --doctor` to check available tools; nothing is installed automatically.

### macOS

Install [Apple Command Line Tools](https://developer.apple.com/xcode/resources/) with `xcode-select --install` for Apple Clang. With [Homebrew](https://docs.brew.sh/Installation):

```sh
brew install zsh python gcc
```

GNU GCC is the native default; select Apple Clang with `--compiler=clang`. Install [PyPy](https://pypy.org/download.html) and put `pypy3` on PATH, or use `--interpreter=python3`. Downloaded interpreter executables can be selected by absolute path. Package availability depends on macOS and CPU architecture.

### Debian / Ubuntu

```sh
sudo apt update
sudo apt install zsh build-essential clang python3 pypy3
```

Check `zsh --version`; use a distribution with zsh 5.9 or newer.

### Windows

Use [WSL2 with Ubuntu or Debian](https://learn.microsoft.com/en-us/windows/wsl/install), then follow the Linux instructions inside WSL. Native Windows is not supported. Browser-to-WSL Companion forwarding depends on your networking setup.

## Check samples

For one complete test, save the input in **`in.txt`** and the expected stdout in **`ans.txt`**. The program's output stays in **`out.txt`**. `cp-run test --cout` displays only the report; omit `--cout` to save it as **`test_out`**. File defaults are editable; use `--out=FILE` to change the result path for one check.

For independent samples, create numbered pairs:

```text
tests/
  1.in    1.ans
  2.in    2.ans
```

```sh
cp-run test=mult --cout         # Run every sample
cp-run test=mult 2 --cout       # Reproduce only sample 2
```

Each sample gets **AC, WA, TLE, MLE or RE**, its own time and peak memory. Preparation failures are **CE**. A failed sample does not skip the next one. Checking defaults to **1500 ms / 256 MiB per process**; ordinary runs are unlimited.

**Import website samples:** install [Competitive Companion](https://github.com/jmerle/competitive-companion#installation), add custom port **27122**, run `cp-run companion main.cpp`, then click the extension on one problem. [Step-by-step setup](docs/TESTING.md#competitive-companion).

The [testing guide](docs/TESTING.md) explains exact file contents, report symbols, bundles, console input and limits. Try the ready-made [sample projects](examples/README.md).

## Find a smaller counterexample

Name your candidate **`main`**, correct reference **`brute`**, and seeded generator **`gen`**, using supported source extensions. `cp-run stress --test-iters=100` discovers them; mixed-language roles work too.

For counted integer sequences, enable reduction:

```sh
cp-run stress --minimize=sequence --stop-on-failure
```

The original failure stays intact. The reducer removes elements, repairs the count and simplifies values while preserving a confirmed wrong answer. Add a validator for problem-specific constraints. [Run the counterexample example](examples/reduction/README.md).

## Choose your tools and checks

```sh
cp-run main.c --compiler=clang
cp-run main.py                        # PyPy, with its normal JIT enabled
cp-run main.py --interpreter=python3  # CPython instead
cp-run main.py -- -- --input data.txt # Arguments for your program
cp-run debug=extra run main.cpp       # Build and run a stricter diagnostic profile
cp-run main.cpp -tm --average=5       # One stdout; median time, maximum peak RSS
cp-run main.cpp --profile=pragma-native
```

C/C++ use **`-O2`** and the newest ISO standard advertised by the compiler, including draft modes. Native debug profiles use sanitizers and checks selected from the **actual C++ library**; Python profiles use interpreter diagnostics. The `pragma` profiles provide native optimization flag sets. Fast-math changes floating-point behavior, and host-tuned binaries may not run on another CPU. [Profile components and safeguards](docs/CLI.md#languages-and-profiles).

**Make it yours:** `cp-run --set-defaults` → **Languages & tools → Language/compiler defaults** selects a preferred language, separate C/C++ compilers and the Python interpreter. Settings also cover profiles, warnings, paths and limits. Use **`{wsp-dir}/data/in.txt`** in a file default to keep it relative to the workspace; [path examples](docs/CLI.md#workspace-rooted-file-preferences). Explicit command options override saved defaults. [Discovery and precedence](docs/CLI.md#source-discovery-and-language-defaults).

Settings live inside the installed script. Before replacing it, export them, install the new version, then import:

```sh
cp-run --export-settings cp-run-settings.json
# Install the new cp-run.zsh with the command above.
cp-run --import-settings cp-run-settings.json
```

## Format your source

Use optional [clang-format](https://clang.llvm.org/docs/ClangFormat.html) for C/C++ or [Ruff](https://docs.astral.sh/ruff/installation/) for Python. Install the formatter first.

```sh
cp-run main.cpp --make-prettier       # Format this file; do not compile or run
cp-run main.py --make-prettier=check  # Check style; do not edit or run
cp-run --make-prettier                # Find a source, format it, then stop
```

Only selected source files are formatted, using project style settings where present. No lint fixes are applied. Black can replace Ruff in **`--set-defaults` → Languages & tools → Interpreter/source/standard/tools**. [Formatter behavior and setup](docs/CLI.md#formatting).

## Build from modules

From a cloned repository, edit **`development/src/`**, then:

```sh
python3 -B development/build.py
python3 -B -m unittest discover -s development/tests -v
python3 -B development/package.py
```

The build generates **`cp-run.zsh`**; packaging creates **`cp-run-1.1.1.zip`**. End users install only the generated script. [Architecture and development rules](docs/DEVELOPMENT.md).

MIT licensed. Reproducible bug reports and contributions are welcome.

<sub>Built with AI assistance; checked through regression tests and real toolchain runs.</sub>
