# cp-run

**Write a solution. Run it. Find the test that breaks it.**

One command for **C++, C and Python**: compile, diagnose, check samples, measure runtime, and reduce counterexamples. Install **one script**; keep your usual editor and source files.

```sh
cp-run main.cpp                       # Compile and run
cp-run debug main.cpp                 # Run with sanitizers and library checks
cp-run compile main.cpp               # Compile; print the executable's path
```

Want to check answers instead of copying them between terminals?

```sh
cp-run test main.cpp --cout           # input.txt → your program; compare with ans.txt
cp-run test=mult main.py --cout        # Check tests/1.in + 1.ans, 2.in + 2.ans, ...
cp-run stress main.cpp brute.py gen.py --test-iters=100
```

Each test gets its **own verdict, time and peak memory**. Wrong answers show numbered input, output and expected lines. Stress failures preserve the seed and a replay command; optional reduction finds a smaller valid counterexample.

[Install](#install) · [Language defaults](#choose-your-language-and-tools) · [Formatting](#format-your-source) · [Full CLI](docs/CLI.md) · [Testing guide](docs/TESTING.md) · [Runnable examples](examples/README.md)

## Install

Download **`cp-run.zsh`** from the [latest release](https://github.com/V1b3-C0d3r/cp-run/releases/latest), then:

```sh
mkdir -p ~/.local/bin
install -m 755 cp-run.zsh ~/.local/bin/cp-run
```

If the command is not found, enable its directory for this terminal:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

Put that line in your shell's startup file (for example `~/.zshrc`) to keep it. To uninstall, remove `~/.local/bin/cp-run`.

**Requirements:** zsh **5.9+**; GCC or Clang for native sources; **PyPy 3** for Python sources by default. CPython is also supported. Measurements, tests, settings and integrations use a separate **Python 3.9+** standard-library service. Optional tools are needed only when you request their features; `cp-run --doctor` lists what is installed.

### macOS

Install [Apple Command Line Tools](https://developer.apple.com/xcode/resources/) with `xcode-select --install` for Apple Clang. With [Homebrew](https://docs.brew.sh/Installation):

```sh
brew install zsh python gcc
```

GNU GCC is the native default; use `--compiler=clang` for Apple Clang. Install [PyPy](https://pypy.org/download.html) and make `pypy3` available on `PATH`, or select `--interpreter=python3`. Package availability depends on macOS and CPU architecture; a downloaded interpreter can also be selected by its executable's absolute path.

### Debian / Ubuntu

```sh
sudo apt update
sudo apt install zsh build-essential clang python3 pypy3
```

Check `zsh --version`; use a distribution providing zsh 5.9 or newer.

### Windows

Use [WSL2 with Ubuntu or Debian](https://learn.microsoft.com/en-us/windows/wsl/install), then follow the Linux instructions inside WSL. Native Windows is not supported. Browser-to-WSL Companion forwarding depends on your networking setup.

## Choose your language and tools

The filename selects its language. With FILE omitted, cp-run prefers C++ and falls back to an unambiguous supported source; [discovery rules](docs/CLI.md#source-discovery-and-language-defaults) explain mixed directories.

```sh
cp-run main.c --compiler=clang
cp-run main.py                        # PyPy 3, with its normal JIT enabled
cp-run main.py --interpreter=python3  # CPython instead
cp-run main.py -- -- --input data.txt # Arguments for your program
```

Run **`cp-run --set-defaults` → Languages & tools → Language/compiler defaults** to choose the preferred language, a compiler for C, a compiler for C++, and the Python interpreter. Explicit filenames and tool options override saved defaults. Changes are saved inside the installed script. Before replacing an installation, export settings, install the new script, then import:

```sh
cp-run --export-settings cp-run-settings.json
# Install the new cp-run.zsh with the command above.
cp-run --import-settings cp-run-settings.json
```

C/C++ use **`-O2`** and the newest ISO standard advertised by the selected compiler, including draft modes. Python uses the selected interpreter's normal defaults; assertion-removing `-O` is never added automatically. [Backend options and boundaries](docs/CLI.md#commands-and-argument-boundaries).

## Check samples and find counterexamples

For a single test, put the complete input in **`input.txt`** and the expected stdout in **`ans.txt`**:

```sh
cp-run test main.cpp --cout
```

For independent tests, create **`tests/1.in`, `tests/1.ans`, `tests/2.in`, `tests/2.ans`**:

```sh
cp-run test=mult main.cpp --cout
cp-run test=mult 2 main.cpp --cout     # Reproduce only test 2
```

Without `--cout`, the report is saved as **`test_out`**. Raw first-run output is **`real-out.txt`**. Checking defaults to **1500 ms / 256 MiB per process**; ordinary runs are unlimited. Each auto/mult test has independent limits.

For stress testing, supply a candidate, a correct reference and a seeded generator:

```sh
cp-run stress main.cpp brute.py gen.py --test-iters=100
cp-run stress main.cpp brute.py gen.py --minimize=sequence --stop-on-failure
```

The [testing guide](docs/TESTING.md) shows exact file contents, report symbols, every test format, replay and reduction. Try the ready-made [examples](examples/README.md).

**Import website samples:** install [Competitive Companion](https://github.com/jmerle/competitive-companion#installation), add custom port **27122**, run `cp-run companion main.cpp`, then click the extension on one problem. [Step-by-step setup](docs/TESTING.md#competitive-companion).

## Diagnose and measure

```sh
cp-run debug main.cpp
cp-run debug=extra main.cpp
cp-run main.cpp -tm --average=5       # One visible stdout; median time, peak RSS
cp-run main.cpp --profile=pragma-native
```

| Profile | What it adds |
| --- | --- |
| `debug` | C/C++ sanitizers and frame pointers; C++ assertions selected from the **actual standard library**. Python uses interpreter diagnostics. |
| `debug=extra` | Stronger warnings and native/library checks; Python warnings become errors. |
| `--profile=pragma` | Native `-O3`, loop unrolling and unknown-pragma warnings. |
| `--profile=pragma-fast` | More aggressive native optimization, including fast-math. |
| `--profile=pragma-native` | Fast profile plus capability-checked host CPU tuning. |

Diagnostic profiles reject known options that disable their checks. They cannot detect every bug. Fast-math changes floating-point behavior; host-tuned binaries may not run on another CPU. [Exact profile rules](docs/CLI.md#languages-and-profiles) and [measurement behavior](docs/CLI.md#measurements-and-limits).

## Format your source

**This is optional source formatting**, using [clang-format](https://clang.llvm.org/docs/ClangFormat.html) for C/C++ and [Ruff](https://docs.astral.sh/ruff/installation/) for Python. Install the formatter you need first; cp-run does not install it.

```sh
cp-run main.cpp --make-prettier=only  # Rewrite this file's formatting; stop
cp-run main.py --make-prettier=check  # Check formatting; do not edit or run
cp-run main.cpp --make-prettier       # Format, then compile and run
cp-run --make-prettier                # Discover a source, format it, then stop
```

Formatters edit only the selected source files and use the project's style configuration when present. They do not run lint fixes. Black can replace Ruff in **`--set-defaults` → Languages & tools → Interpreter/source/standard/tools**. See [formatter behavior and setup](docs/CLI.md#formatting).

## Build from modules

From a cloned repository, edit **`development/src/`**, then:

```sh
python3 -B development/build.py
python3 -B -m unittest discover -s development/tests -v
python3 -B development/package.py
```

The build generates **`cp-run.zsh`**; packaging creates **`cp-run-1.1.zip`**. End users install only the generated script. [Architecture and development rules](docs/DEVELOPMENT.md).

MIT licensed. Reproducible bug reports and contributions are welcome.

<sub>Built with AI assistance; checked through regression tests and real toolchain runs.</sub>
