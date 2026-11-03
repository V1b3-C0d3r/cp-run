# cp-run

Compile a contest solution, feed it input and check its output from the terminal. Works with C++, C and Python on macOS or Linux.

## First run

Download **cp-run.zsh** from the [latest release](https://github.com/V1b3-C0d3r/cp-run/releases/latest). From the download directory:

```sh
mkdir -p ~/.local/bin
install -m 755 cp-run.zsh ~/.local/bin/cp-run
export PATH="$HOME/.local/bin:$PATH"
```

In the directory containing `main.cpp`, run `cp-run` and type the input. You can paste it while compilation is in progress. For another filename, pass it explicitly.

| To… | Run |
| --- | --- |
| Compile and run | `cp-run solution.cpp` |
| Run with diagnostic checks | `cp-run debug run solution.cpp` |
| Check one sample | Save input in `in.txt`, expected output in `ans.txt`, then run `cp-run test --cout` |
| Check numbered samples | Put `in1.txt`, `ans1.txt`, etc. in `tests/` and run `cp-run test=mult --cout` |
| Find a counterexample | Put `main.cpp`, `brute.cpp` and `gen.cpp` together and run `cp-run stress --stop-on-failure` |
| Change files, tools or profiles | `cp-run configure` |

**Tools.** Use zsh 5.9 or newer. Native builds default to GNU GCC; select Clang with `--compiler=clang`. Python solutions default to PyPy; select CPython with `--interpreter=python3`. Tests and settings need Python 3.9+. Check your installation with `cp-run --doctor`.

**Upgrading.** Settings live in the installed script. Run `cp-run --export prefs.json` before replacing it (`--export-settings` on versions before 1.2), then `cp-run --import prefs.json`.

[Command reference](docs/CLI.md) · [Test formats and verdicts](docs/TESTING.md) · [Runnable examples](examples/README.md) · [Build from source](docs/DEVELOPMENT.md)
