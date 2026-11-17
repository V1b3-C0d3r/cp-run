# Formatting and review

[Commands](CLI.md) · [School checks](SCHOOL_FORMAT.md) · [Home](../README.md)

## Choose a mode

| Mode | Use it for | Tools |
| --- | --- | --- |
| `--clang` | Project formatting for C/C++; Ruff/Black for Python | clang-format; Ruff or Black |
| `--school` | C/C++ school layout and numbered checks | clang-format 15+, Clang, GNU GCC |

Downloads default to clang. Change the default in **configure → tools → language settings**. The school compilation profile and formatter share compiler flags, but selecting a profile does not select a formatter.

```sh
cp-run format --school solution.c
cp-run format --school solution.c --review
cp-run format solution.c --check
```

Omit FILE for source discovery; `-` recalls the last source. Workspace/profile selection remains supported. Use `format stress MAIN BRUTE GEN` for all stress roles.

Safe layout edits are automatic. Syntax/tool failures, concurrent edits and detected token/AST changes prevent unsafe publication. Neither mode runs submitted programs or Makefiles.

## Errors first, then review

Start `format --review` in a terminal. Errors are listed first; warnings stay hidden until errors are corrected or explicitly justified. Edit the file in your editor while cp-run waits.

| Decision | Error phase | Warning phase |
| --- | --- | --- |
| `a` / `accept` | Recheck; advance only when the actual error disappears | Recheck; advance only when the actual warning disappears |
| `d` / `deny` | Stop; errors cannot be dismissed | Record disagreement and continue |
| `j [TEXT]` / `justified [TEXT]` | Save a local error exception | Save a local warning exception |
| `c [TEXT]` / `comment [TEXT]` | Add a persistent comment; error stays active | Add a persistent comment; warning stays active |
| `a all`, `d all`, `j all [TEXT]` | Apply to remaining errors | Apply to remaining warnings |
| `export FILE` | Save current report | Save current report |
| `q` / `quit` | Stop | Stop |

Long forms and `accept-all`, `deny-all`, `justified-all` also work. Optional reviewer text is saved in the report. `j all` applies the same text to every selected finding. Empty text produces a compact marker without an empty colon.

`a` never assumes a fix succeeded. An unchanged finding stays open. If an edit introduces an error during warning review, errors take priority again.

### Comments and temporary notes

| Marker | Effect |
| --- | --- |
| `/* school-error-justified 3.4: external API name */` | Suppress this style error at this location |
| `/* school-justified 5.9: buffer grows in another module */` | Suppress this warning at this location |
| `/* school-error-comment 3.4: assigned name */` | Reviewer text; does not suppress |
| `/* school-warning-comment 5.9 */` | Empty reviewer comment; does not suppress |

Markers sit immediately before the affected line. Their rule, source location and severity determine scope. Strings cannot create exceptions; a source cannot justify a different header's violation.

**`--annotate` enables review with temporary notes beside active findings.** `a --annotate` enables a note for the selected finding. Temporary notes are removed after processing, including EOF, cancellation and Ctrl-C. Repeated runs do not accumulate them; leftovers after a killed process are cleared on the next format. Comments from `c` and exceptions from `j` remain.

Parser/compiler/tool failures cannot be justified or annotated as numbered style exceptions. A rejected `j` or `c` returns to the prompt immediately, without rerunning analysis. Fix the source/environment and use `a`. A justification is an explicit reviewer exception, not proof that the original code followed the rule.

## Export before and after decisions

```sh
cp-run format --school solution.c --review --report review.json
cp-run format --school solution.c --check --report check.json
```

The same `--report` flag works for normal formatting, checking and the compilation gate. JSON includes initial findings before decisions, phase, final state, reviewer text and decisions. It is updated during processing, preserving incomplete reviews.

Warnings stay out of the report while the error phase is active. The initial warning list is saved before warning processing begins.

Existing reports require `--overwrite`. Sources, binaries and active input/output files cannot be report destinations. Report replacement is atomic. `export FILE` uses the same safeguards.

## Check before compiling

```sh
cp-run solution.c --strict-format
cp-run solution.c --strict-format=school
cp-run compile solution.cpp --strict-format=clang --report format.json
```

An omitted mode uses the saved formatter default. Warnings neither block compilation nor start review.

Errors interrupt the build and, in a terminal, start the full formatter. **The original build command ends afterwards**; run it again when ready. Without a terminal, errors are printed/exported and the command exits.

The initial gate is read-only. Every selected source role is checked before any build. Existing binaries are preserved on failure. Binary-only runs cannot request a source check. Without the flag, normal compilation is unchanged.

## Scope and limits

School reports observable evidence, not blanket obligations to prove meaning or ownership. `0`, `1`, `2` and `-1` need no named constants. `const`/`#define` definitions of `2` and `-1` also need no enum conversion.

`N` is allowed as an enum constant. Ambiguous constants `I` and `O` are rejected, including object-like macros.

English meaning, message intent, unresolved ownership and recipe correctness need human judgment. The [numbered coverage table](SCHOOL_FORMAT.md) separates automatic checks from exclusions.

## Speed and fresh verification

School reuses a result only while source bytes, tool identities, policy version, include environment and compiler-discovered dependencies remain unchanged. Header or Makefile edits invalidate it. Review decisions are never cached.

C++ parsing uses the selected GNU compiler's available libstdc++ headers, including GNU helpers such as `std::__lg`. It disables Clang's default C++ headers to avoid mixing libstdc++ with libc++. If a remote/container compiler's headers are unavailable locally, Clang keeps its own header search.

Prepared C++ headers are reused across runs while compiler, include environment and dependencies remain unchanged. Up to eight preparations / 256 MiB are kept privately; active runs retain their own artifact. Code and source macros are parsed again after edits. Used external enum values and exception ancestry remain checked. If a later include fails, an earlier valid prefix can still avoid dumping the standard library.

A parser limitation remains an error even when GNU GCC accepts the source. Unchanged, dependency-validated failures can be cached; missing AST checks never become a successful result.

Use `--no-cache` to bypass saved findings and rerun source verification. Dependency-validated compiler preparation can still be reused. The result cache holds at most 64 source entries under the normal XDG cache/state directory. Unavailable or corrupt preparation is rebuilt; clock-dependent inputs are not reused.

## Exit status

| Status | Meaning |
| --- | --- |
| `0` | No errors; interactive review completed if requested |
| `1` | Errors, stopped/unfinished review, or interrupted strict build |
| `2` | Invalid command, report path or option combination |
| `130` | Ctrl-C |

Noninteractive formatting may return 0 with warnings. `--check` never prompts or edits; layout differences and errors return nonzero.
