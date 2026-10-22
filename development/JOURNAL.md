# 1.1 implementation journal

## Baseline

- Repository baseline: 369b7ed; branch: develop/1.1. Existing 1.0 snapshots remain frozen.
- 361 baseline tests passed locally before implementation (134.890 s).
- GitHub authentication verified; checked stages will be committed and pushed throughout development.

## In progress: language launch plans

- Added C driver/standard selection, interpreter argv, per-role stress launches, Python syntax-only preparation, source discovery and independent file redirections.
- Added settings groups for language/profile/action routing; pragma profiles explicitly request -Wunknown-pragmas.
- Native observer and timing implementation are unchanged. Real C/Python smoke runs passed; focused regressions are being added.

## Remaining at the initial checkpoint

- Settings/menu migration validation and complete language regressions.
- Per-case reports/verdicts/stderr, CE finalization and stress continuation.
- Mult layouts, checked bundle/manual separators, Companion receiver and fixtures.
- Bounded validity-aware counterexample reduction; formatting/doctor; docs/examples and platform CI.

## First implementation checkpoint

- Full local checkpoint: 393 tests passed (one optional PyPy skip), 134.573 s. Expanded language and settings suites also pass (12 and 27 tests).
- Implemented C/Python/PyPy launch plans, guarded language profiles, per-action/profile routing, independent redirects and Python-aware target history.
- Implemented mult templates, checked counted bundles and manual-marker conversion, shared detailed reports, independent test limits, CE reports, stress continuation and bounded failure bundles.
- Implemented loopback Companion reception with actual HTTP regression fixtures and bounded sequence/case/line reduction. Reduction was checked end-to-end against a deliberately wrong solution; original input remains unchanged.
- README/CLI/testing documentation and runnable examples cover the new interface and source build commands. HTTP imports are lazy so unrelated measurements avoid their startup cost.
- GitHub's initial baseline workflow passed: https://github.com/V1b3-C0d3r/cp-run/actions/runs/39766583319 . GitHub CLI API calls intermittently hit TLS timeouts; bounded curl requests can read public Actions status without credentials.
- Owner additionally authorized publishing release 1.1 after validation. Still required: final platform CI on changed code, remaining edge-case audit, extracted-archive verification, release checklist and publication.

## Platform audit and hardening (in progress)

- Changed-code CI: 39771093697. Linux ARM exercised PyPy successfully. Found a portable-test wording issue (GCC says "ignoring #pragma") and a macOS Companion startup delay caused by HTTPServer reverse DNS.
- Replaced receiver binding with numeric-loopback binding without reverse DNS; added a deterministic no-DNS regression and a header-read timeout.
- Added import rollback coverage for interruption after replacement, independent redirection protection, exact Python replay/history options, guarded Python short-option clusters, and retained hidden-repeat evidence.
- Added checked service/manual defaults, a source-free pack path, operation/profile routing tests, old-schema migration checks and reduction interruption handling. Latest targeted results before final checkpoint: 12 language, 30 feature, 27 pragma tests passed (optional tools skipped where unavailable).
- Ruff 0.17.1 installed only in /tmp/cp-run-v11-tools for formatter integration checks; no user/system installation changed.
- Remaining gates: final local/extracted suite, examples/packaging/benchmark, fixed-code platform workflow, checklist review, merge and authorized release publication.

### Defaults and documentation review

- Made PyPy the factory Python interpreter; added omitted-source language preference and independent C/C++ compiler defaults with explicit CLI precedence and legacy import inheritance.
- Added language/compiler menu coverage, real PyPy default coverage and abbreviated Python-warning guard regressions. Native/Python diagnostics remain separate; ordinary Python startup gains no version-probe process.
- Rewrote README around runnable workflows; expanded formatter edit/check/build contracts, installation links, test-file examples and report notation. Fixed a malformed native-tool discovery diagnostic found during review.
- Fixed the stale debug + --no-w test to enforce the agreed diagnostic-profile conflict; full source regression and four-platform CI remain release gates.

- Full local source checkpoint: **414 tests passed**, one unavailable native-formatter skip; 163.851 s. The last two added language regressions and final warning-abbreviation guard are checked separately before pushing.
- Verified every local Markdown file/heading link. Confirmed old CI failed only on GCC warning wording and Companion reverse-DNS startup; both fixes are included.

### Post-commit audit

- Reviewed all maintained documentation, CLI help, default/profile composition, source discovery, formatting, stress replay and generated/archive manifests after commit 56f28a9.
- Clarified profile components, raw auto/mult output framing and --no-w restrictions. Improved save preview to show C, C++ and Python settings independently.
- Source-free packaging and local links validate. Extracted archive regression suite is running; final archive will be regenerated after journal/preview changes.

- CI 39785394615: both Ubuntu architectures passed. macOS ARM exposed an existing EPERM-before-waitable-exit race in process-group signalling. Added an owned, unreaped leader fallback only on group EPERM; genuine leader permission denial remains an error. A controlled regression covers delayed exit publication without timing sleeps.

- Final behavior audit found that `run -` retained interpreter history but ignored newly supplied --interpreter-arg options. Fixed insertion before the recorded source and added an exact argv/runtime regression plus execution-replacement rejection.
- The rebuilt archive passed **417 tests** (one unavailable local clang-format skip), 148.756 s; **27 isolated documented workflows** passed, including mixed-language stress, minimization/replay, real HTTP sample import, formatting and settings round trip. Build and package reproduce byte-for-byte after extraction.
- Startup benchmark (15 samples, informational): native 1.0 median 8.330 ms, native 1.1 9.415 ms; direct native 2.038 ms. PyPy launch median 23.724 ms through cp-run versus 13.810 ms directly. Native unlimited execution still starts no service Python; no unsupported speedup claim.

- A language-specific settings audit caught native operand rules being applied to Python's standalone -B/-I switches. The shared editor now receives the backend grammar explicitly; added menu, toggle and actual-interpreter regressions. No execution-path work was added.
- Owner requested more visible beginner commands and a stronger README. The lead now demonstrates source discovery, sample checking, stress and reduction before installation/reference details.

## Workspace-rooted paths and interactive repeated runs

- Added literal {wsp-dir}/PATH support to saved source/input/output/answer/report paths, stress-role defaults and numbered templates. CLI file roles use the same expansion. Workspace lookup is lazy and separate from artifact destination validation, preserving exact -o bypass.
- Shared rooted template handling across mult, pack/unpack and Companion; kept parent/symlink/collision checks and added nested-workspace, menu/export and mixed-root coverage. Published version snapshots and release assets remain untouched.
- Replaced the repeated-TTY rejection with one visible, bounded input-recording run, followed by hidden warm-up/measurements using the saved bytes. The capture is outside statistics. No-input programs need no EOF; cancellation stops the relay.
- Hidden successful stderr is discarded; hidden execution errors replay complete stderr and preserve status. Added real PTY/no-input/failure/cancellation checks and an exact median-ownership regression. Test/stress repetition semantics are unchanged.

- Full first checkpoint: 441 tests, three errors: an obsolete test still expected terminal rejection, and two local-HTTP tests were denied by the filesystem-only sandbox grant. Updated the obsolete contract test and requested network access for actual loopback verification.
- Extended recorded input to warm-up-only ordinary runs as well, so warm-ups use the same data and no runtime failure is silently discarded. Updated ordinary-launch regressions only; checking/stress execution and verdict contracts remain unchanged.
- Added --compile, --debug[=PROFILE] and --run command aliases, accepted first or after FILE. Conflicting operations fail before tool discovery; backend/runtime tails and native option operands stay literal. Eight focused alias regressions pass, including Python syntax-only compilation and run --find.
- Before the final behavior change, the isolated archive passed all 452 tests in 260.109 s. A source-tree checkpoint was invalidated by temporary ENOENT for the installable script; the final gate uses an isolated archive.
- Owner changed the debug command contract before commit: debug/--debug now only prepare and print the target path; debug run and combined --debug --run explicitly build and execute. Kept debug profile/routing ownership, added a shared build-only guard and two argument boundaries for debug run. Updated documentation and execution-specific regressions; final checks are pending.
- Final changed-code archive: 456 tests in 265.874 s; 454 passed, and two newly added native assertions needed macOS /var -> /private/var canonicalization. Corrected only their expected path, then reran all 16 real GCC/Clang regressions: passed in 18.343 s. No application code changed after that full run. Real C/Python smoke checks independently confirm build-only debug and explicit debug-run status propagation.
- Verified 26 local Markdown links/anchors, generated-script reproducibility, exact script/new-test inclusion in the archive, zsh syntax and clean diff whitespace. All 39 frozen snapshot hashes match. Public v1.1 assets and frozen version folders are unchanged; the follow-up is a source commit.
