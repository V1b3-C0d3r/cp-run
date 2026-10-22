# 1.1 implementation journal

## Baseline

- Repository baseline: 369b7ed; branch: develop/1.1. Existing 1.0 snapshots remain frozen.
- 361 baseline tests passed locally before implementation (134.890 s).
- GitHub authentication verified; checked stages will be committed and pushed throughout development.

## In progress: language launch plans

- Added C driver/standard selection, interpreter argv, per-role stress launches, Python syntax-only preparation, source discovery and independent file redirections.
- Added settings groups for language/profile/action routing; pragma profiles explicitly request -Wunknown-pragmas.
- Native observer and timing implementation are unchanged. Real C/Python smoke runs passed; focused regressions are being added.

## Remaining

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
