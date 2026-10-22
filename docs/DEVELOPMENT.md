# cp-run development standards

Applies to 1.1 development. Progress and verification are recorded in the implementation journal.

## Architecture and ownership

- Maintain modular zsh/Python sources; distribute one generated `cp-run.zsh`. Never patch embedded generated code instead of its source module.
- zsh owns lightweight parsing, defaults, tool discovery and native execution. Python owns supervision, structured checking, report rendering and advanced integrations.
- Keep explicit build manifests. A module needs a distinct responsibility, not just a few functions. Prefer clear functions and small records over a plugin framework or generic pipeline machinery.
- Parse, resolve defaults, validate, plan paths, prepare, execute and render as separate phases. Validate before side effects. Pass structured build/launch/case outcomes instead of inferring status from diagnostic text.
- Use one shared implementation for routing, case templates, codecs, verdicts and process observation. Do not duplicate these inside Companion, stress or settings.

## Naming, language and comments

- Public documentation, help, identifiers and comments are English. User-facing diagnostics name the failed option/file/role and a concrete correction.
- Use descriptive snake_case functions/variables, UPPER_CASE settings/constants, and explicit unit suffixes such as `_ns`, `_bytes`, `_ms`. Do not reuse shell system names such as `path`, `status`, `HOME` or `CODEX_HOME` for local state.
- Comment every substantial logical block: purpose, ownership and nonobvious constraints. Function documentation states inputs/results and meaningful side effects. Avoid line-by-line narration.
- Put short side comments beside subtle or intentionally editable choices: defaults, unit conversions, timer boundaries, precedence, capability assumptions and cleanup behavior. Longer reasoning belongs above the block or in the contract.
- Keep prose concise. README demonstrates value first; CLI defines behavior; TESTING shows exact files and commands. Explain a rule once and link to it.

## Shell and argument handling

- Use zsh-native operations on the common path. Preserve array element boundaries from CLI through child argv. Never execute a rendered command string.
- No `eval`, untrusted `source`, shell=True subprocesses, or unquoted expansion for user values. Display quoting is only for display.
- Required option values accept `=VALUE` and separate VALUE. Recognize optional operands with a documented grammar; preserve explicit-given markers until default resolution finishes.
- The existing `--` boundaries are a public contract. Program arguments are opaque. Guarded diagnostic profiles inspect relevant backend arguments without consuming a different option's operand.
- Use GNU-style `--help`, `--version`, readable usage errors and stderr diagnostics. Existing short options and the two-boundary extension are intentionally documented exceptions to a generic GNU parser.
- Reserve stdout for the program, compile's target path, explicit data actions or the requested report. Commands appear only with `--show-command`.

## Python and process supervision

- Keep Python 3.9-compatible standard-library code unless the documented minimum is deliberately changed. User interpreters are separate from cp-run's service interpreter.
- Use argv lists and explicit file objects. Large input/output/stderr and report data stream through files; do not accumulate arbitrary output in RAM or deadlock on unread pipes.
- Preserve stdin, descriptor isolation, signals and child ownership. Keep the early-exit/reaping fixes and never signal a reused PID/process group.
- Store time as integer nanoseconds and memory as integer bytes. Rendering converts units; it does not alter limits. Measure child execution, not compilation, history callbacks, comparison or report rendering.
- Each process execution has its own nominal limits and kill factors. Repetition aggregation must never hide a failure or replace the single visible stdout.
- Scope cleanup to resources this invocation owns. Cancellation retains useful evidence and closes temporary descriptors/listeners.

## Files, settings and imports

- Distinguish absent, false, empty and inherited settings. Resolve fields independently using the documented precedence. Validate settings import/export through one schema and migrate older exports explicitly.
- Treat imported JSON, template values, website metadata and filenames as data. Never fetch a supplied URL, execute embedded commands, or trust remote paths.
- Preflight collisions and physical containment before mkdir/write. Protect source, input, answer, artifact and report aliases, including hardlinks and symlink parents.
- Stage on the target filesystem; use atomic replacement where it actually applies. Do not call a multi-file replacement crash-atomic without a transaction/recovery mechanism.
- Default overwrite refusal and explicit replacement permission cover only the planned target files. Never remove unrelated user files while refreshing imported tests.

## Testing and performance

- Add a focused regression for each changed contract or bug. Assert argv, bytes, outcomes and phase ownership; avoid tests that merely restate implementation.
- Timing/signal races use controlled clocks and events. Real smoke tests use broad sanity bounds; CI scheduling is not a correctness oracle for a 140 ms ceiling.
- Exercise both language tools and the single installed artifact. Mocks prove wrapper behavior; real compilers/interpreters prove support. Label unavailable external matrix coverage honestly.
- Include negative tests for invalid values, failed preparation, cancellation, unsafe paths, resource failures, incomplete comparisons and malformed external data.
- Benchmark CLI startup and child timing separately. An optimization needs evidence and must not weaken measurements, compatibility or useful errors.
- Run the affected tests during development. Full source/archive tests, platform CI and documented examples are release gates; do not repeatedly rerun everything without a new reason.

## Git and release workflow

- Work in the actual Git checkout on a dedicated 1.1 development branch. Published 1.0 artifacts remain frozen.
- As authorized by the owner, make small coherent commits and push completed, checked stages during implementation. Commit the fix, relevant tests and contract documentation together; avoid committing a knowingly broken intermediate state as a completed milestone.
- Use clear English imperative commit subjects. Record what changed, what was checked and remaining blockers in a short development journal. Never put credentials, personal state, generated local history or scratch logs in commits.
- Keep generated distribution artifacts synchronized at explicit packaging checkpoints, not as a second editable source tree. Prepare release notes from actual final behavior and test evidence.
- Final review compares the implementation against the approved release checklist, validates the extracted package and records remaining platform limitations. A plan checkbox alone is not proof of completion.

Reference: [GNU command-line interface standards](https://www.gnu.org/prep/standards/html_node/Command_002dLine-Interfaces.html).
