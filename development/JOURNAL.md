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
