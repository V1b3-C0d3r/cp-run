# School formatter architecture

**Scope.** This document maps every numbered rule in the supplied PDF and every occurrence in the GCC command to its implementation contract. Behavioral evidence is in `development/tests/test_school*.py`; release verification is recorded in `development/JOURNAL.md`.

Source policy is *Стиль форматирования программ*, 8 November 2026. Paragraphs 1.1–6.6 and their examples define the requirements. Formatting examples are reference data.

## User contract

- Run cp-run format [FILE] --clang or --school. --check never writes. The --make-prettier spelling delegates to the same action. Preserve discovery, quoted paths, workspace prefixes, history -, profile selectors and all previously supported formatting options.
- Repository default is clang. Personal default is school. Formatting mode and compilation profile are independent. Rename the personal informatics profile to school, normalize its flags to the shared policy, migrate Code Runner references and keep a backup.
- School is a formatter plus a fail-closed policy checker. It does not execute the submitted program or a project Makefile.
- Mechanical violations are errors. A semantic obligation that cannot be established statically is a blocking review request tied to a rule and a source location.
- A review is an explicit author assertion in an actual source comment, for example '// school-reviewed 3.1: calc_sqrt names the integer square-root calculation'. It requires a substantive reason. It applies only to review obligations in that file. Strings cannot create reviews. Unknown rule IDs and attempts to waive mechanical-only rules are errors.
- An assertion cannot suppress a proven violation, even when the same rule also has semantic obligations. For example, reviewing an indirect call under 5.8 cannot allow a direct strcpy call.
- Exit 0 means formatting, compiler checks and all applicable policy obligations have been resolved. It is not a mathematical proof of English meaning, program correctness or resource lifetime. The summary distinguishes automatic checks from author assertions.
- Normal format first publishes a verified layout and then reports remaining policy errors/reviews with a nonzero status. This lets an author progressively improve unreadable but parseable code. Compiler warnings do not prevent safe whitespace fixes.
- Syntax errors, tool failures, altered AST semantics and concurrent edits prevent publication. If Clang cannot parse a GNU-only construct that GCC accepts, a conservative token-only layout may be published with explicit incomplete-check diagnostics; it can never produce a successful school check.
- Check mode never writes. When formatting differs, diagnostic locations are explicitly identified as referring to the formatted candidate. After normal format, locations refer to the published file.

## Components and data flow

1. **Native action planner** resolves files and CLI options. It uses the existing cp-run source planner. Clang mode delegates to existing clang-format/ruff/black behavior.
2. **Source reader** retains original bytes, UTF-8 byte offsets, line endings, permissions and physical identity. A real token scanner distinguishes comments, directives, strings and character literals. Invalid encoding is an actionable error.
3. **Clang front end** produces JSON ASTs with source maps, symbol IDs, types and initializer structure. System declarations are excluded by origin, not by matching spelling. Macro expansion or missing locations cannot silently disable checks.
4. **Layout engine** runs a fixed clang-format policy, then targeted AST-range edits where the PDF differs from clang-format. Reparse after edits. Never rename identifiers, change expressions, insert frees/memset/return values or move resource operations automatically.
5. **Policy engine** dispatches typed AST nodes and project metadata to the individual rules below. Each finding has file, line, column, rule ID, error/review category, evidence and a concrete suggested edit. One registry enumerates all 68 rules and binds their handlers and tests.
6. **Project auditor** inspects related local headers, declarations, dependencies and Makefile text read-only. It resolves include guards and direct ownership; ambiguous include graphs require review. It never executes build recipes.
7. **Compiler verifier** checks staged candidates with the exact C flag vector below, preserves both -lm occurrences and records the GNU version. Link a complete single-file program, compile independent modules, and diagnose incomplete project context separately. C++ uses its own driver and language-valid flag subset.
8. **Publisher** verifies all original snapshots before any write. Atomically replace each changed file beside the original and preserve permissions. A multi-file update is not crash-atomic; surface partial publication failures. Check mode produces diagnostics without writes. Clean up candidates, temporary binaries and descriptors on every exit.

The one-file distribution embeds these modules. Optional tools are needed only by formatting. They are resolved before editing begins. Tool failures/timeouts must be distinguishable from policy failures. Source paths are argv elements; no shell evaluation, network fetches or implicit installation.

## Rule architecture

Action codes are **F** for a semantics-preserving layout fix followed by verification, **E** for a proven violation with an editing suggestion, and **R** for a blocking author-review obligation. A rule may have both E and R cases. For each test ID below, tests must include a violating input, a conforming input and the stated exception where one exists. Tests assert behavior, diagnostics, source preservation and idempotence, rather than merely checking registry membership.

### Characters and layout

| Rule | Detection and action | Acceptance test |
| --- | --- | --- |
| 1.1 | Scan raw bytes for C0/DEL except LF/CR. E for forbidden controls in code, comments or literals. Preserve escaped spellings. | T1_1 NUL/BEL/DEL fail; LF/CR and textual escape sequences pass. |
| 1.2 | F indentation tabs to spaces. Re-scan final bytes. A literal/comment tab that cannot be changed without changing data is E with an escape suggestion. | T1_2 indentation tab becomes spaces; tab in string fails; escaped backslash-t passes. |
| 2.1 | F structural block indentation to four spaces. Verify token nesting and exceptions for continuations, labels and access labels. | T2_1 nested blocks, structs, switch and C++ classes; idempotence. |
| 2.2 | Count Unicode characters per physical line excluding CR/LF. F legal wrapping; E when a token/comment/literal cannot be safely split to 100. | T2_2 exact 100/101 boundaries, Cyrillic comments and unbreakable literal. |
| 2.3 | F continuation indentation to +8 from the first segment, without column alignment. Check continuation tokens after final edits. | T2_3 long condition, call, assignment and nested continuation at nonzero base indent. |

### Names

| Rule | Detection and action | Acceptance test |
| --- | --- | --- |
| 3.1 | AST identifies global variable/function declarations. R for meaningful purpose, reasonable length and understandable abbreviations; main has its standard meaning. Suggest a purpose-based name. | T3_1 global f produces R; justified calc_sqrt is accepted; local scalar is not treated as global. |
| 3.2 | Check all user identifiers for ASCII spelling; R for English words/conventional abbreviations versus transliteration. Do not pretend a dictionary proves meaning. | T3_2 transliterated function needs review; English rationale resolves it; strings/comments never act as identifiers. |
| 3.3 | Resolve enum members and scalar constants by AST type. E unless UPPER_SNAKE_CASE. Avoid misclassifying a pointer to const as a constant object. | T3_3 RED/POLL_INTERVAL pass; red fails; pointer-to-const remains a variable. |
| 3.4 | E for non-lowercase variable/label spelling. For functions only, nonstandard spelling is R requiring the teacher-approved exception. C++ constructors/operators are language constructs. | T3_4 bad variable fails despite review; teacher-approved function exception; ctor/operator handling. |
| 3.5 | R for type-encoding prefixes/suffixes on variables and fields. Type-based patterns help explain evidence but never establish the author's intent by regex alone. | T3_5 Hungarian name produces R; a genuine word with a coincidental prefix can be justified. |
| 3.6 | E for types/tags outside PascalCase; R under 3.2 for word segmentation/meaning. Exclude implicit/compiler-owned types. | T3_6 Node/BinaryOperation pass casing; node/binary_operation fail; system typedefs excluded. |
| 3.7 | E for explicitly prohibited l/I/O. R for other visually confusable names. Case distinctions do not hide the explicit prohibition. | T3_7 all three forbidden names fail; counter passes ambiguity check; glyph runs require review. |

### Declarations and initialization

| Rule | Detection and action | Acceptance test |
| --- | --- | --- |
| 4.1 | F record/class layout. E for shared structure field declaration lines, combined record/object declarations and C++ field m-prefix/trailing underscore. Preserve typedef struct Node ... Node and constructor parameter suffixes shown in PDF. | T4_1 struct/typedef/class positives; combined Foo ... foos and bad C++ fields fail; ctor re_ remains legal. |
| 4.2 | F named/multimember enum definitions vertically. Anonymous one-member inline form is legal but may be expanded. AST keeps values and ordering unchanged. | T4_2 named enum, typedef enum, anonymous one/multiple members and explicit values. |
| 4.3 | F pointer stars toward the declarator, including multiple indirection and comma-separated declarators. Do not confuse multiplication with pointer declarations. | T4_3 int* p, char * * s and mixed pointer/nonpointer declarations. |
| 4.4.1 | Compare syntactic and semantic initializer trees. E for omitted nested braces. F layout; R when clarity of data grouping remains semantic. Account for designated and partially implicit initializers. | T4_4_1 flat matrix fails; nested/designated lists pass structure; omitted values are distinguished from omitted braces. |
| 4.4.2 | F scalar/pointer declarator and assignment start onto the same line; preserve expression evaluation and declaration order. | T4_4_2 split scalar assignment becomes one declaration start; long RHS uses legal continuation. |
| 4.4.3 | F short string initializers onto the declaration line; allow safe adjacent literals for long strings. Never change decoded bytes. | T4_4_3 short/long/escaped/concatenated strings have equal compiler-decoded contents. |
| 4.4.4 | Identify local C record objects and initialization/use order. E for a definitely violating initializer/use-before-zero; R if memset coverage or prior state cannot be proved. C++ nontrivial objects require a safe author decision. Never insert memset blindly. | T4_4_4 memset-before-field-write passes; brace-only local struct fails; aliases/branching require R; C++ object is not corrupted. |
| 4.4.5 | Classify initializer expressions through AST constant evaluation. E when a multiple-variable declaration contains nonconstant initialization. Suggest splitting without reordering. | T4_4_5 calls and variable expressions fail; literal/enum constants pass; comma inside a call is not a declarator separator. |

### Functions

| Rule | Detection and action | Acceptance test |
| --- | --- | --- |
| 4.5.1 | F return type, qualifiers/storage class, name and braces; verify function body indentation. E if return is absent, including void. Return values are never invented. Macros hiding the definition require R. | T4_5_1 pointer/static/inline functions; explicit void return; missing return; macro-expanded declaration. |
| 4.5.2 | AST proves zero parameters before adding void in empty definition parameter lists. Preserve prototypes where C's unspecified-parameter semantics would change. | T4_5_2 main()/main(void), function pointers, old-style nonempty parameters and C++ zero parameters. |
| 4.5.3 | Reconstruct logical name/parameter header. Above 70 characters, use AST parameter ranges for separate +8 lines and move opening brace to its own line. Preserve callbacks, defaults, variadics and qualifiers. E if an indivisible parameter/name cannot fit. | T4_5_3 boundaries 70/71, callback parameter, default expression, variadic, qualifiers; stable on repeated format. |

### Statements

| Rule | Detection and action | Acceptance test |
| --- | --- | --- |
| 4.6.1 | F if spacing and brace layout; reparse equivalent condition/body structure. | T4_6_1 single and multiline conditions. |
| 4.6.2 | F closing brace, else and opening brace onto prescribed layout. Preserve dangling-else binding. | T4_6_2 nested dangling else and comments. |
| 4.6.3 | F else-if chain; preserve branch order and associations. | T4_6_3 three-branch chain and nested if within else. |
| 4.6.4 | F while spacing/braces. Do not silently replace intentional null loops with different logic. | T4_6_4 one-statement loop and empty-loop decision. |
| 4.6.5 | F do/while spacing, braces and terminal semicolon. | T4_6_5 nested do/while, comments and semicolon retained. |
| 4.6.6 | F for header/body layout, including empty clauses. | T4_6_6 all three clauses, declarations and for(;;). |
| 4.6.7 | F switch/case/default indentation; retain fallthrough, labels and break semantics. No automatic break insertion. | T4_6_7 shared cases, explicit fallthrough and default. |
| 4.6.8 | F mandatory braces for if/while/do/for when AST proves the body boundary. Macro/preprocessor ambiguity is E/R, never an unsafe rewrite. | T4_6_8 all body kinds, nested else and directives spanning bodies. |
| 4.6.9 | F separate expression statements onto separate lines; do not split semicolons inside a for header or string. | T4_6_9 adjacent statements, for header, semicolon literal. |
| 4.6.10 | F ordinary labels to column one and onto their own lines, preserving labeled null statements. case/default follow 4.6.7. | T4_6_10 nested label, label before semicolon, case label distinction. |
| 4.6.11 | Resolve goto target symbol and source order. E for backward jump; R for forward jump's cleanup/nested-exit purpose. Unresolved computed goto cannot pass silently. | T4_6_11 forward cleanup review, backward failure and GNU computed goto review. |
| 4.6.12 | F try/catch layout. E for user-defined exception caught without const reference. Analyze class hierarchy for definite handler shadowing; R for ambiguous/template ordering. | T4_6_12 derived-before-base positive, base-before-derived failure, bad catch type, catch-all and dependent types. |

### Expressions

| Rule | Detection and action | Acceptance test |
| --- | --- | --- |
| 4.7.1 | F binary operator spacing from parsed tokens, preserving overloads and preprocessor text. | T4_7_1 arithmetic, comparison, logical and overloaded operators. |
| 4.7.2 | F member access and subscripts without surrounding spaces. | T4_7_2 dot, arrow, multidimensional subscript. |
| 4.7.3 | F one space after comma and for-header semicolons. Do not edit literal content. | T4_7_3 declarators, call args, for and comma character/string. |
| 4.7.4 | F unary operator adjacency; distinguish postfix, prefix, dereference and multiplication. | T4_7_4 *p++, ++i, !x, address-of and binary multiplication. |
| 4.7.5 | F function name adjacent to its opening parenthesis; control keywords keep required space. | T4_7_5 call/definition versus if/while, function-pointer call. |
| 4.7.6 | F parenthesis interior spacing without deleting semantically necessary parentheses. | T4_7_6 nested expressions, casts and comments. |
| 4.7.7 | F one space after C-style cast. Preserve cast type, qualifiers and pointer stars. | T4_7_7 unsigned char pointer cast and nested casts. |
| 4.7.8 | AST identifies dereferenced pointer addition and dot on dereferenced pointer. E with array/arrow suggestion. Do not perform overload-sensitive C++ rewrites automatically. | T4_7_8 both prohibited forms fail; equivalent [] and arrow pass; operators inside strings ignored. |
| 4.7.9 | AST/precedence identifies definitely redundant parentheses. E with location; assignment-warning suppression, macros or overload ambiguity receive R. Preserve necessary grouping. | T4_7_9 PDF negative/positive examples, a-(b-c), assignment condition and macro argument. |

### Language and libraries

| Rule | Detection and action | Acceptance test |
| --- | --- | --- |
| 5.1 | Resolve literal AST contexts. Permit 0/1, enum/declared constants, 2 as stderr descriptor and -1 as error sentinel. E for other undeclared numeric literals. Intent-dependent sentinel/descriptor use is R. | T5_1 decimal/hex/floating values, enum/const context, write(2,...), return -1 and ordinary literal 2. |
| 5.2 | E for integer #define or const integer constants. Integer enums are accepted; R for meaningful enum names, rather than TEN-style numeric aliases. Include guards are not integer constants. | T5_2 numeric macros, const values, pointer-to-const, guard macro and enum purpose. |
| 5.3 | Tokenize includes and resolve system/project ownership. E for known wrong delimiters; R for nonstandard installed-header ownership. No inference from header suffix alone. | T5_3 stdio with quotes, project tree header with angle brackets, POSIX and C++ headers. |
| 5.4 | Resolve output call and stream when possible. E for provably diagnostic output to stdout; R for result/diagnostic intent or indirect/custom streams. | T5_4 literal diagnostic, result output, stderr use, wrapper and computed format. |
| 5.5 | Track complete diagnostic writes, adjacent literal formats and known newline functions. E for definite missing newline; R for dynamic/split diagnostic completion. | T5_5 perror/puts behavior, fprintf with/without newline, split/dynamic strings. |
| 5.6 | Track final result writes to stdout/files. E for definite missing newline; R for split output and character-stream exception. | T5_6 PDF printf examples, file stream, putchar processing exception and concatenated literals. |
| 5.7 | Control-flow checks that main exits through explicit return. Evaluate literal/enum exit values and enforce 0 <= code < 128. E for proven violation; R for undecidable paths/values. | T5_7 0/127/128/-1 via named constants, both if branches, unknown return value and falloff. |
| 5.8 | Resolve function symbols/aliases. E for banned calls and scanf/fscanf %s without positive width. Parse %%/suppression/length modifiers correctly. R for indirect target/format that cannot be resolved. | T5_8 each banned function; %s/%0s/%10s/%%s/%*s, dynamic format and function pointer. |
| 5.9 | Classify malloc allocation target. E for list/tree element allocation. R for the explicit realloc-based growable-array exception or unknown target; otherwise suggest calloc. | T5_9 linked node malloc, growable array rationale, calloc alternative. |
| 5.10 | Detect sizeof(type), available object/pointer and allocation assignment context. E where sizeof(value) is demonstrably available; R if that context is uncertain. | T5_10 PDF allocation forms, function parameter, type-only layout calculation and macro type. |
| 5.11 | Inspect the allocation byte-count argument, not an unrelated sizeof elsewhere in the call. Require count times sizeof(element); calloc's two operands provide the multiplication. E for missing shape; R for mismatched/unknown element provenance. | T5_11 char realloc, calloc(count,sizeof(*p)), wrong argument sizeof and array element type. |
| 5.12 | Inspect comment tokens for likely disabled/debug code. R when text resembles code; ordinary examples/documentation may be justified. Never interpret string contents as comments. | T5_12 disabled printf/assignment, prose example, URL/string and review comments. |
| 5.13 | Identify I/O inside non-main helpers. R for whether the helper is general-purpose or explicitly an output routine; E if a known general-purpose utility directly writes. | T5_13 list helper I/O, print_results rationale, error return alternative. |
| 5.14 | Identify user global variable definitions, excluding extern declarations and constants. R for necessity and parameter-passing alternative. | T5_14 real global, extern declaration, local static and immutable constant. |
| 5.15 | Analyze local allocation size, element size and storage lifetime. E for a proven fixed buffer <=64 KiB that can use stack; R when size, purpose or stack suitability is unknown. | T5_15 small char buffer, threshold 65536/65537, dynamic count and escaping lifetime. |
| 5.16 | Resolve array extents through types/constant expressions. E for local variable-length arrays, including multidimensional cases. Do not confuse a constant enum bound or parameter declaration with a local VLA. | T5_16 input-sized array, enum bound, int a[n][4], pointer-to-array and function parameter. |
| 5.17 | Classify resources by type, acquisition calls and ownership propagation. E for late/uninitialized resource declarations and proven leaks/use-after-release. R for borrowing, aliasing, custom ownership and precise last use. Static analysis evidence does not waive unresolved lifetime obligations. | T5_17 PDF examples, initialized sentinel, cleanup on success/error, aliasing, FILE/fd/custom resource, C++ RAII. |
| 5.18 | In C, resolve allocation call under casts. E for explicit casts of malloc/calloc/realloc results. Preserve C++ casts and unrelated C conversions. | T5_18 all three allocators with/without cast; C++ new/cast and unrelated integer cast. |

### Multi-module programs

| Rule | Detection and action | Acceptance test |
| --- | --- | --- |
| 6.1 | Enumerate selected module context and siblings. Non-main C module needs sibling .h; main may omit it. E for missing pair or bodies in a declaration-only header; R for public/private declaration partition when ambiguous. | T6_1 main with helper/no header, separate module pair, missing header, header with body and static-inline exception decision. |
| 6.2 | Preprocessor nesting verifies a matching guard encloses the entire header. pragma once is an accepted equivalent. E for mismatches, premature closing or unguarded declarations. | T6_2 valid/mismatched guard, nested conditionals, pragma once, content after final endif. |
| 6.3 | Compare source basename/own-header path and actual include directives. E if module.c omits module.h; comments/strings do not count. | T6_3 own include, transitive-only include, commented-out include and main exemption. |
| 6.4 | Map referenced declarations to owning project headers through AST source locations and dependency graph. E for known missing direct include; R for macro-generated/ambiguous ownership or incomplete project scope. | T6_4 transitive dependency, direct include, macro ownership and missing compilation context. |
| 6.5 | Audit header dependencies against types/entities needed by its declarations. E for a proven implementation-only include; R for templates/macros/forward-declaration tradeoffs. Do not remove includes automatically. | T6_5 unnecessary stdio include, FILE declaration requiring stdio, implementation-only I/O and template-dependent header. |
| 6.6 | Locate the relevant project Makefile, parse rules read-only and require all/clean. E for missing targets; R for recipes' completeness and cleanup safety. Never run make clean to test the rule on user files. | T6_6 absent file/target, grouped targets, include/variables, complete project and unrelated-file preservation. |

## Shared school preset

One immutable policy record owns the C and C++ flags. The school formatter and the school compilation profile consume that same record. The named profile uses GNU GCC and bypasses unrelated global warning/optimization defaults; explicit user compiler arguments remain explicit overrides and are shown in the command. Reject a Clang backend for the pinned school preset. C++ selects its documented driver/flag subset; school does not target Python.

The preset's policy flags are read-only in configure. Users can copy school to another profile for custom flags without modifying the school verifier. Destination and relative-path routing remain editable profile settings. Import normalizes an existing school preset against the canonical policy, with local backup before migration. Integration test P_school_sync compares ordered compiler argv for the preset and verifier, both languages, default GCC selection, explicit Clang rejection, copy behavior and import preservation.

## GCC flag architecture

The reference environment is GNU C 11.3.0. The verifier must establish GNU identity, log the actual version and preserve the exact ordered C argv below. Clang's AST pass does not replace GCC checks. Compilation profiles may add user flags during ordinary compilation, but school verification uses its fixed policy.

Test IDs G01–G23 are planned real-GCC contract tests. Positive and negative fixtures invoke the complete policy; diagnostics should expose the relevant warning when GCC provides it. Parser/formatting reviews are tested separately so a review cannot masquerade as a compiler warning.

| ID  | Flag occurrence              | Role and planned verification                                                                                                                                                        |
| --- | ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| G01 | -O2                          | Optimize candidate as on the school server. Assert exact argv and compile a preprocessor fixture requiring __OPTIMIZE__. No performance claim.                                       |
| G02 | -Wall                        | Enable the baseline warning family. Unused-variable fixture fails; used variable passes.                                                                                             |
| G03 | -Werror                      | Promote enabled warnings to errors. Assert nonzero compiler status; no source publication.                                                                                           |
| G04 | -Wformat-security            | Nonliteral printf format without arguments fails; literal format passes.                                                                                                             |
| G05 | -Wignored-qualifiers         | Ignored return-type qualifier fixture fails; legitimate pointee qualifier passes.                                                                                                    |
| G06 | -Winit-self                  | Self-initialized scalar fixture fails with the enabled uninitialized/self-init diagnostics; proper initializer passes.                                                               |
| G07 | -Wswitch-default             | Switch without default fails; explicit default passes. Do not insert default behavior automatically.                                                                                 |
| G08 | -Wfloat-equal                | Direct floating equality fixture fails; integer comparison passes. Never invent epsilon/tolerance.                                                                                   |
| G09 | -Wpointer-arith              | void/function-pointer arithmetic fixture fails; arithmetic on a complete object type passes.                                                                                         |
| G10 | -Wtype-limits                | Always-false unsigned comparison fixture fails; meaningful bound comparison passes.                                                                                                  |
| G11 | -Wempty-body                 | Accidental empty conditional body fails; explicit compound statement passes.                                                                                                         |
| G12 | -Wno-logical-op              | Preserve the disabled logical-op warning. A suitable logical-op warning probe must not fail specifically for logical-op; argv retains the switch. This does not waive style rules.   |
| G13 | -Wstrict-prototypes          | Empty C declaration parameter list fails; (void) passes. C++ excludes this C-only switch.                                                                                            |
| G14 | -Wold-style-declaration      | Misplaced storage-class specifier fails; conventional declaration passes. C++ excludes this switch.                                                                                  |
| G15 | -Wold-style-definition       | K&R definition fails; typed prototype-style definition passes. C++ excludes this switch.                                                                                             |
| G16 | -Wmissing-parameter-type     | Missing K&R parameter type fails; all types explicit passes. C++ excludes this switch.                                                                                               |
| G17 | -Wmissing-field-initializers | Missing structure-field initializer warning fails; complete initialization passes. PDF memset obligation remains a separate rule.                                                    |
| G18 | -Wnested-externs             | Nested extern declaration fails; file-scope prototype passes. C++ excludes this switch.                                                                                              |
| G19 | -Wno-pointer-sign            | Preserve the signedness-warning exception with a probe that has no other incompatible-pointer warning. It does not waive type safety or PDF checks. C++ excludes this C-only switch. |
| G20 | -Wno-unused-result           | Preserve the ignored warn_unused_result exception. A marked-result probe passes that warning gate; correct result handling also passes.                                              |
| G21 | -std=gnu99                   | Compile GNU C99; fixture checks __STDC_VERSION__ == 199901L and a GNU extension. C++ instead uses its documented GNU++17 policy.                                                     |
| G22 | first -lm                    | Place math-library linkage after the source/object. Link a runtime-dependent math call so constant folding cannot hide a missing library. Never execute the candidate.               |
| G23 | second -lm                   | Preserve the second occurrence and order exactly. Assert ordered argv, rather than assuming semantic deduplication is harmless.                                                      |

C++ retains G01–G12, G17, G20, G22 and G23, uses the GNU C++ driver and replaces G21 with -std=gnu++17. C-only G13–G16/G18/G19 are absent. Tests verify the full C++ vector independently.

## Verification gates and completion

1. Add rule fixtures T1_1–T6_6 before extending the corresponding handler. Each rule's positive, negative and exception fixtures must pass; a registry row alone is not test coverage.
2. Add G01–G23 real-compiler fixtures. Verify GNU 11.3.0 separately from the developer's installed GCC version. If the reference compiler is unavailable, report that gate as unverified.
3. Integration tests cover command/alias equivalence, default selection, mode overrides, check-only behavior, source discovery/history, relative/quoted/workspace paths, C/C++ headers and Python rejection in school.
4. Failure tests cover invalid UTF-8, controls/literals/comments, macro source maps, missing tools, timeout, malformed AST, compiler failure, concurrent edits, permissions, symlinks and partial multi-file publication.
5. Run mandatory source checks, full tests, package extraction/rebuild comparison and platform CI. Inspect every failure and rerun only affected tests after a fix. Hosted-runner acquisition failure is infrastructure, not a passed test.
6. Update the coverage ledger with actual test evidence. Keep main CI fixes separate from the formatter branch. Install locally only a checked build with configuration backup and the personal school default. Do not publish a new release without authorization.

Completion requires all 68 rule contracts and G01–G23 gates to have implementation plus passing evidence, or an explicitly documented external verification blocker. Architectural coverage, static enforcement, author review and reference-compiler verification are separate claims.

## Practical formatting and safety

The normal workflow is format, inspect the compact per-rule review list, edit/justify the remaining issues, and format/check again. The formatter never invents meaningful names, enum purposes, return values, cleanup operations or output behavior.

Compare source-local AST structure before and after automatic edits. Normalize only the planned empty-parameter definition conversion and single-statement control-body braces; preserve literals, declaration/reference identity, operator order and branch binding. Source-location-sensitive builtins require an explicit review. Reject a formatter that returns a different program.

Normal format may write a candidate with unresolved naming/library/review obligations, but returns nonzero and says which files were formatted. Check mode reports without writing. Every source in a multi-source action must be safely prepared before publication begins; atomicity remains per file.

Review diagnostics are grouped by rule and file with representative locations, keeping noisy real code usable. Hard errors and compiler diagnostics retain their actionable evidence. A review never turns a mechanical failure into success.

Long literal tokens are never rewritten automatically. Split adjacent literals yourself if a line cannot meet the 100-character limit. GNU-only syntax that the Clang frontend cannot parse receives conservative token layout plus an explicit incomplete-check error.

### Behavioral coverage

| Area | Tests |
| --- | --- |
| Each of 68 numbered paragraphs | `test_school_rule_matrix.py`: individually reported T1_1 through T6_6 |
| Every supplied flag, including both math libraries | `test_school_compiler.py`: G01 through G23 |
| Boundary cases and language exceptions | `test_school_edges.py`, `test_school_layout.py` |
| Real unreadable code and semantic preservation | `test_school_safety.py` |
| Pending/resolved/invalid reviews and proven errors | `test_school_reviews.py` |
| Tool/encoding failures, concurrent edits, permissions and partial publication | `test_school_failures.py` |
| Shared compile/format policy and personal routing | P_school_sync and `test_school_settings.py` |

These tests exercise examples and boundaries, not every possible C/C++ program. Meaningful English names, diagnostic intent, custom ownership, project-wide completeness and similar semantic decisions require author review. GNU 11.3.0 runs in a separate CI job, independently of the locally installed compiler.
