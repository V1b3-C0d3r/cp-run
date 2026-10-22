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

## Release 1.1.1

- Owner requested publishing the current fixes. Prepare a new patch release so v1.1 and its original tag/assets stay reproducible.
- Changed release metadata and archive filename, removed the stale hardcoded version from the settings-menu heading, and made the version regression read the maintained build version. Application behavior is unchanged from e2eb7ac.
- e2eb7ac CI is green on Ubuntu ARM/x86 and macOS Intel; macOS ARM is queued at this checkpoint. Release verification/publication is in progress.
- Owner added configurable checked-output naming before publication. DEFAULT_OUTPUT now controls both redirected stdout and the test/stress result; --out accepts both value forms and workspace prefixes. Fresh defaults are in.txt/out.txt/ans.txt/test_out. Console checking prints only the protocol, with numbered output included there and no separate raw stdout copy.
- Extended preflight/sidecar collision protection to the selected result path, retained atomic publication across workspace volumes, and updated protocols, examples, default fixtures and documentation. New focused path/console/publication regressions are being verified before commit/release.
- Output/default checkpoint: 467 tests, with one stale command-display regex still naming input.txt/output.txt. Corrected that expectation and its focused rerun passed; all application behavior at this checkpoint was unchanged by that test-only correction.
- Owner simplified formatting before publication: --make-prettier now always formats and exits; check is read-only; only/before modes are removed. Formatter dispatch runs before compiler/artifact planning and cannot fall through into a build. Stress selects all source roles, and missing tools are still resolved before any edit. Updated documentation and format-only regressions are in progress.
- Final extracted 1.1.1 archive passed **475 tests** in 266.461 s with all locally available tool integrations enabled. Eight formatter regressions verify no compiler/program execution, check immutability, source discovery/history, stress roles, dependency preflight and removed modes. Eleven new output/publication regressions cover renamed defaults, workspace paths, console-only reports, protected roles, cross-volume replacement and older preference filenames.
- Five documented workflows passed separately: whole-file checking, macro/redirected file I/O, workspace-rooted mult output and counterexample reduction. Corrected the example guide to describe both lines in its sample answer. Source changes are ready for commit, current platform CI and a new immutable 1.1.1 snapshot/release.

## Fixed task-folder simplification (in progress)

- Replaced filename templates, source anchors and inherited test subtrees with one DEFAULT_TEST_FOLDER and --test-f. Numbered files are fixed inN.txt/ansN.txt; artifact routing stays independent.
- Pack/unpack now process both streams by default, use saved input/answer filenames when omitted, accept one/two bundle operands and attached =in/=ans selectors. Paired writes share preflight/rollback; malformed or mismatched second streams cannot modify the first. Removed manual-file conversion, not lossless framing.
- Old preference imports discard removed template/subtree fields and migrate explicit test folders. Exports use schema 3. Formatter syntax is exactly bare --make-prettier or --make-prettier=check.
- Reworked CLI/testing documentation, tables and runnable examples. The owner subsequently authorized updating README too; its numbered filenames and short folder/pack examples now match the simplified contract.
- Focused storage tests initially exposed a new-test Python 3.9 compatibility issue (Path.hardlink_to); changed the fixture to os.link. Two loopback tests require the network-enabled verification run. Final full-project audit and archive verification are pending.

- Additional owner request: ordinary/run -f=auto now accepts one --cin/--cout override, normalized to the existing output-only/input-only execution path. Both together fail before any preparation; test/stress retain their existing semantics. Focused source/Python/binary/repetition regressions cover this late addition.

## Final CLI contract (supersedes intermediate spellings above)

- configure is now the standalone settings command; pack/unpack are bare data commands, with optional =in/=ans selectors. Old --set-defaults/--pack/--unpack/--text spellings produce migration diagnostics.
- -f/--file-io accept no =VALUE or mode keywords. Factory action remains macro; configure offers macro or auto. Saved auto optionally accepts IN/OUT filenames and one --cin/--cout override. Both overrides together, or either in macro mode, fail before preparation. Test/stress console behavior is unchanged.
- Updated current documentation and fixtures; historical journal entries retain the spellings used at their checkpoints. The first final storage archive passed 494 tests; late console routing passed eight focused tests. A final interface/archive verification is now pending.

## Final audit and verification

- Final extracted archive: **507 tests passed**, no skips, in 285.182 s on macOS Apple Silicon with real GCC/Clang, CPython/PyPy and optional formatter integrations. All 20 isolated documented workflows passed, including configure, macro/auto I/O, console overrides, lossless folder round trips, mult/auto and confirmed reduction.
- Reviewed CLI phase/argv ownership, path containment and paired writes, settings migration, language/profile selection, repeated-run stdout/stderr, runtime limits/verdicts, reporting bounds, build manifests and package contents. Fixed a counted-reader FIFO hang risk with regular-file preflight; tests cover it without blocking. Removed obsolete source-anchor transport and corrected stale module/formatter diagnostics.
- Documentation reviewed against parser/defaults and exercised commands; all 29 local links/anchors and Markdown table widths validate. Root README now uses fixed names and final bare commands. Formatter remains bare edit or attached =check only. No GitHub upload instructions were added to project docs.
- Native runtime observer and memory backend are unchanged. New routing normalizes once into existing execution paths; ordinary unlimited native launches still avoid Python. The tested modules/tests and generated script match the working sources exactly.
- Workspace cleanup verified all 33 old Work/Development files against the frozen 1.0 archive before removing the redundant copy. Removed obsolete applied patches/check helpers and Finder artifacts outside frozen snapshots; grouped old verification records by release. All 39 frozen file hashes remain unchanged.
- Final packaging/reproducibility, commit, platform CI and publication evidence are recorded under Work/Verification/1.1.1. Previous draft assets must be replaced with this build before publication.
