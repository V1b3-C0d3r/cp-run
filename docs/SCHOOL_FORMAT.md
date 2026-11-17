# School formatter architecture

[User workflow](FORMAT.md) · [CLI](CLI.md) · [Development](DEVELOPMENT.md)

This table maps all 68 numbered paragraphs of the supplied school codestyle to observable checks. An omitted semantic judgment is a documented limit, not a warning that every user must approve.

## Pipeline and ownership

| Component | Responsibility |
| --- | --- |
| Native planner | Select sources/roles and paths; keep runtime arguments opaque |
| Clang frontend | Select GNU C++ headers; parse through a dependency-validated preamble; retain used enum values and exception ancestry |
| Layout | Fixed clang-format policy, parameter/label edits, token and AST verification |
| Policy | Structured file/line/column/rule/severity/evidence findings |
| Project audit | Read-only header ownership, guards, necessary includes and literal Makefile targets |
| Compiler verification | Shared GNU flags; compile a staged unit without linking or running it |
| Resource analysis | Run relevant Clang checkers when source contains resource/pointer evidence |
| Result cache | Source/tool/policy/environment key, compiler dependency metadata and bounded private storage |
| Review | Error repair/exception loop, then warning decisions; no inferred success after accept |
| Publisher | Concurrent-edit preflight, per-file atomic replacement, preserved permissions |
| Report | Initial snapshots plus final decisions; protected destinations and atomic updates |

Automatic notes are temporary. Reviewer comments and severity-specific local exceptions are persistent. Only actual comment tokens create metadata. Exceptions do not apply across files or to another occurrence. Syntax/tool failures are not numbered style exceptions.

The strict compilation gate first checks every source read-only. Warnings pass. Errors open the full formatter only with a terminal and always end the original build command.

## Numbered rules

| Rule | Automatic check | Boundary / manual part |
| --- | --- | --- |
| 1.1 | Forbidden controls | Escaped spellings are data. |
| 1.2 | Tabs outside safely editable layout | Literal tabs require a source edit or explicit exception. |
| 2.1 | Four-space block layout | clang-format off is an error in school mode. |
| 2.2 | 100-character physical lines | Reviewer metadata is excluded; long data literals remain intact. |
| 2.3 | Eight-space continuations | No column alignment. |
| 3.1 | Function/global names shorter than three characters; function f | No assessment of meaningfulness or abbreviation quality. |
| 3.2 | Non-ASCII identifiers; distinctive whole transliterated words or multiple Russian-word tokens | No general English dictionary or broad substring matching. |
| 3.3 | UPPER_SNAKE_CASE scalar constants and enum members | Pointer-to-const is not a constant object. |
| 3.4 | lower_snake_case variables/labels; function casing warning | A teacher-approved function spelling can be justified. |
| 3.5 | Type-prefix warning only when the prefix matches the declared type | Ordinary names do not require type-encoding assertions. |
| 3.6 | PascalCase types/tags | No word-meaning check. |
| 3.7 | Forbidden I/O/l identifiers and concrete ambiguous glyph runs | No general name-readability inference. |
| 4.1 | Record layout, separate fields and object declarations; C++ field prefixes | Constructors/operators retain language-imposed forms. |
| 4.2 | Enum layout and value ordering | Single-member enum form remains legal. |
| 4.3 | Pointer-star layout | Multiplication is an expression, not a declarator. |
| 4.4.1 | Explicit nested initializer braces | No judgment about data-grouping clarity. |
| 4.4.2 | Declaration/initializer layout | Expression order is preserved. |
| 4.4.3 | String initializer layout | Literal contents are never rewritten. |
| 4.4.4 | C local structure zero-before-use; conditional-zeroing warning | No blanket memset requirement for C++ objects. |
| 4.4.5 | Separate nonconstant initialized declarations | Constant-expression grouping stays legal. |
| 4.5.1 | Definition layout and explicit return; location-sensitive builtin warning | No blanket function-like-macro warning. |
| 4.5.2 | Explicit void in empty definitions | Incompatible prototype-less calls require a source edit. |
| 4.5.3 | 70-character header threshold and one parameter per continuation | Default literal spelling is preserved. |
| 4.6.1 | if layout | — |
| 4.6.2 | if/else layout | — |
| 4.6.3 | else-if layout | — |
| 4.6.4 | while layout | — |
| 4.6.5 | do/while layout | — |
| 4.6.6 | for layout | — |
| 4.6.7 | switch/case/default layout | — |
| 4.6.8 | Braced control bodies, including empty bodies | Branch binding is checked after edits. |
| 4.6.9 | One expression statement per line | — |
| 4.6.10 | Labels on separate unindented lines | — |
| 4.6.11 | Backward goto error; forward/computed-goto evidence warning | The author judges the cleanup/loop-exit exception. |
| 4.6.12 | User exception const references and proven catch hierarchy/order | Unresolved hierarchies do not generate a generic warning. |
| 4.7.1 | Binary-operator spacing | — |
| 4.7.2 | Member/index spacing | — |
| 4.7.3 | Comma/for-semicolon spacing | — |
| 4.7.4 | Unary-operator spacing | — |
| 4.7.5 | Call spacing | — |
| 4.7.6 | Parenthesis spacing | — |
| 4.7.7 | C-cast spacing | — |
| 4.7.8 | Prohibited pointer/index/member forms | — |
| 4.7.9 | Provably redundant parentheses | Uncertain overloaded-operator grouping stays manual. |
| 5.1 | Numeric literals other than 0, 1, 2 and -1 require named constants | No inference about -1 as an error sentinel. |
| 5.2 | Integer enum/const/define policy; number-word enum-name warning | const/define values 2 and -1 are exempt; enum meaning is not assessed. |
| 5.3 | Known standard/local include delimiters | Unknown installed header ownership stays manual. |
| 5.4 | No automatic intent finding | Whether output is a result or diagnostic is manual. |
| 5.5 | Provable diagnostic newline violation | Unknown/split/character-stream output does not cause a blanket warning. |
| 5.6 | Provable result newline violation | Same output-analysis limits as 5.5. |
| 5.7 | Known main exit constants outside [0,128) | Unknown return ranges and unproved control flow stay manual. |
| 5.8 | Known prohibited calls/aliases and unbounded literal scanf string conversions | Unknown indirect calls and dynamic formats are not presumed unsafe. |
| 5.9 | malloc linked-node error; no-matching-realloc warning | Known growable-array use is accepted. |
| 5.10 | Allocation sizeof(TYPE) where an object is available | Other unknown replacement opportunities stay manual. |
| 5.11 | Byte-count shape using count and sizeof | No generic assertion about unknown count/type correspondence. |
| 5.12 | Concrete commented-code pattern warning | Prose examples can be justified. |
| 5.13 | Output from the policy-named getline helper | Unknown helper purpose is not inferred from any I/O call. |
| 5.14 | Mutable global-state evidence warning | Necessity is a reviewer decision, not an automatic proof obligation. |
| 5.15 | Proven small nonescaping local char allocations | Unknown size, element width or escape behavior stays manual. |
| 5.16 | Local VLAs | Pointer-to-VLA types and function parameters are not local array storage. |
| 5.17 | Known resource declaration violations and analyzer findings | No blanket pointer/RAII/borrowing or precise-last-use review. |
| 5.18 | C casts of malloc/calloc/realloc results | C++ conversions retain their language semantics. |
| 6.1 | Known missing C module/header pair; C bodies in headers | C++ inline/template bodies are not presumed violations. |
| 6.2 | Whole-header guards or pragma once | — |
| 6.3 | Missing own-header include | — |
| 6.4 | Known missing direct owner include | Macro/ambiguous ownership and other consumers stay manual. |
| 6.5 | Demonstrably implementation-only includes in simple interfaces | Conditional/template include necessity stays manual. |
| 6.6 | Missing Makefile or known missing all/clean targets | Recipes and unresolved dynamic targets are never executed or certified. |

## Shared compiler policy

The school profile and verifier read one canonical C/GNU C++ policy. C++ omits C-only warnings and uses GNU C++17. Both math-library occurrences are preserved. Profile paths stay editable; copy school to customize its flags.

Formatting compiles a staged translation unit to retain optimization-dependent warnings; it does not link the project or execute recipes. Real linking remains part of compilation and the reference-compiler tests.

| Test | Flag | Observable contract |
| --- | --- | --- |
| G01 | -O2 | Optimization macro is enabled |
| G02 | -Wall | Unused-variable warning is active |
| G03 | -Werror | Warnings fail verification |
| G04 | -Wformat-security | Unsafe nonliteral format is rejected |
| G05 | -Wignored-qualifiers | Ignored type qualifiers are diagnosed |
| G06 | -Winit-self | Self-initialization is diagnosed |
| G07 | -Wswitch-default | A switch requires default |
| G08 | -Wfloat-equal | Floating equality is diagnosed |
| G09 | -Wpointer-arith | Invalid pointer arithmetic is diagnosed |
| G10 | -Wtype-limits | Impossible type-range tests are diagnosed |
| G11 | -Wempty-body | Empty control bodies are diagnosed |
| G12 | -Wno-logical-op | Logical-op warning stays disabled |
| G13 | -Wstrict-prototypes | C parameter prototypes are required |
| G14 | -Wold-style-declaration | Storage-class placement is checked |
| G15 | -Wold-style-definition | Old-style definitions are rejected |
| G16 | -Wmissing-parameter-type | Implicit parameter types are rejected |
| G17 | -Wmissing-field-initializers | Omitted structure fields are diagnosed |
| G18 | -Wnested-externs | Block-scope externs are diagnosed |
| G19 | -Wno-pointer-sign | Pointer-sign warning stays disabled |
| G20 | -Wno-unused-result | Unused-result warning stays disabled |
| G21 | -std=gnu99 | GNU C99 is selected |
| G22 | first -lm | Runtime-dependent math call links |
| G23 | second -lm | Second math-library argument is preserved |

## Verification map

| Area | Test files |
| --- | --- |
| Every numbered paragraph | test_school_rule_matrix.py: T1_1 through T6_6 |
| Every supplied flag occurrence | test_school_compiler.py: G01 through G23 |
| Error/review decisions and temporary notes | test_format_review.py |
| Compilation gate and source preservation | test_strict_format.py |
| Dependency-aware result reuse and invalidation | test_format_cache.py |
| GNU headers, small ASTs, preamble invalidation and header semantics | test_school_frontend.py |
| Rule boundaries, semantic exclusions and exceptions | test_school_policy.py, test_school_edges.py, test_school_reviews.py |
| Safe layout and actual unreadable code | test_school_layout.py, test_school_safety.py |
| Failures, concurrency and publication | test_school_failures.py |
| Profile synchronization | test_school_settings.py and P_school_sync |

The GNU 11.3.0 job runs independently of the developer's installed GNU version. Full source/archive and platform evidence is recorded in development/JOURNAL.md. Published historical releases are unchanged.
