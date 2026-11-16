# School formatter architecture

`cp-run format [FILE] --clang|--school [--check]` replaces the old formatting action. `--make-prettier` remains an alias. Existing discovery, history `-`, workspace paths and profile options use the same source planner. Formatting never executes the program. Factory default is clang. Configure the mode alongside formatter executables in the language settings.

## Pipeline

1. Resolve inputs and dependencies.
2. clang keeps existing project-style clang-format and Python formatter behavior.
3. school parses C/C++ into a Clang JSON AST with UTF-8 byte locations, supplies void in parameterless definitions, and uses a fixed clang-format style.
4. AST policy checks produce source locations, PDF rule numbers and editing suggestions. GNU GCC verifies candidates with the supplied warning flags, including both -lm. Candidates containing main are linked but never executed. Modules are compiled.
5. All candidates must pass before writes. Preflight original bytes and atomically replace each changed file, preserving permissions. Multi-file replacement is not crash-atomic. Check mode never writes.

School requires clang-format 15+ (InsertBraces), Clang JSON AST, and GNU GCC. CP_RUN_GCC selects an explicit GNU compiler. Local compiler versions may differ from the school's GNU 11.3.0; exact-version compatibility requires testing with that version. C uses the supplied complete flags. C++ uses applicable warnings and GNU++17, excluding C-only options. Formatting does not implicitly select a compilation profile.

## Coverage of the supplied PDF

The policy is *Стиль форматирования программ*, 8 November 2026. A successful invocation means the implemented mechanical checks passed. It does not certify semantic requirements.

| Rules | Handling |
| --- | --- |
| 1.1–1.2 | Convert indentation tabs; diagnose remaining controls. |
| 2.1–2.3 | Four-space indent, eight-space continuation, 100 columns. Diagnose unbreakable text. |
| 3.1–3.2, 3.5 | Meaningful English names and Hungarian notation require author review. |
| 3.3–3.4, 3.6–3.7 | AST declaration casing and ambiguous l/I/O checks. Semantic constants require review. |
| 4.1–4.3 | Structure/enum/pointer layout; diagnose fields on the same line. Combined tag/object declarations and C++ field prefixes require review. |
| 4.4.1–4.4.4 | GCC initializer checks; nested braces, memset, grouping and initialization intent require review. |
| 4.4.5 | Diagnose multiple declarations with call initializers. Other complex initializers require review. |
| 4.5.1–4.5.2 | Return-type line, braces, void and presence of return. Return-path completeness requires review. |
| 4.5.3 | Continuation wrapping. Special 70-character header threshold requires review. |
| 4.6.1–4.6.10 | clang-format control braces, statements, switch and label layout. |
| 4.6.11–4.6.12 | Diagnose goto for review. Forward-only jumps and catch semantics require review. |
| 4.7.1–4.7.7 | Operator, punctuation, cast and pointer spacing. |
| 4.7.8–4.7.9 | Pointer rewrites and redundant parentheses require review. |
| 5.1 | Diagnose numeric literals outside enums conservatively. Contextual stderr/error-sentinel exceptions require review. |
| 5.2 | Diagnose numeric define and const integer variables. Enum meaning requires review. |
| 5.3 | Header spelling and ownership require review; preserve include order. |
| 5.4–5.7 | Diagnose literal output missing newline. Stream purpose, split output, character-stream exceptions and exit-code semantics require review. |
| 5.8 | Diagnose banned functions and scanf %s without width. |
| 5.9–5.11 | Diagnose malloc, sizeof(type), allocations without sizeof. Exceptions and exact allocation dimensions require review. |
| 5.12–5.15 | Diagnose globals. Debug comments, helper I/O and unnecessary heap allocation require review. |
| 5.16 | Diagnose nonconstant array bounds. |
| 5.17 | Resource declaration placement, validity and lifetime require author review. |
| 5.18 | Diagnose C allocation-result casts. |
| 6.1–6.3, 6.6 | Require sibling header/Makefile for non-main C modules; diagnose missing own-header include. Include guards and Makefile rules require review. |
| 6.4–6.5 | Dependency ownership and minimal includes require project-wide review. |

School is an assisted formatter/linter. It reports conservative diagnostics rather than guessing semantic rewrites. Current manual-review requirements are explicitly reported after mechanical checks pass.
