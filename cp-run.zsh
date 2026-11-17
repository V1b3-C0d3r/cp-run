#!/bin/zsh -f
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 cp-run contributors
# One C, C++ or Python source, one selected output, and an optional run. Requires zsh 5.9.

# Start from native, predictable options instead of inheriting interactive
# customizations. Expected failures are checked explicitly, without ERR_EXIT.
emulate -LR zsh
setopt NO_UNSET PIPE_FAIL EXTENDED_GLOB
unsetopt ALIASES
typeset -r PROGRAM=cp-run VERSION=1.5.2
typeset -r SCRIPT_PATH=${0:A} # Settings follow the real script when invoked through a symlink.

# CP_RUN_SETTINGS_BEGIN
# Managed by cp-run configure; ordinary launches read these native values directly.
typeset -gA MODE_CPP_FLAGS=(school '')
typeset -gA MODE_C_FLAGS=(school '')
typeset -gA MODE_C_GCC=(school '-O2 -Wall -Werror -Wformat-security -Wignored-qualifiers -Winit-self -Wswitch-default -Wfloat-equal -Wpointer-arith -Wtype-limits -Wempty-body -Wno-logical-op -Wstrict-prototypes -Wold-style-declaration -Wold-style-definition -Wmissing-parameter-type -Wmissing-field-initializers -Wnested-externs -Wno-pointer-sign -Wno-unused-result -std=gnu99 -lm -lm')
typeset -gA MODE_C_CLANG=(school '')
typeset -g FORMAT_MODE=clang
typeset -g DEFAULT_COMPILER=GCC
typeset -g DEFAULT_STANDARD=auto
typeset -g DEFAULT_LANGUAGE=c++
typeset -gA LANGUAGE_COMPILERS=()
typeset -g DEFAULT_SOURCE=main.cpp
typeset -g DEFAULT_INPUT=in.txt
typeset -g DEFAULT_OUTPUT=out.txt
typeset -g DEFAULT_ANSWER=ans.txt
typeset -g DEFAULT_REPORT=test_out
typeset -g DEFAULT_SEPARATOR='\n\x1e\n'
typeset -g DEFAULT_INTERPRETER=pypy3
typeset -g C_STANDARD=auto
typeset -g C_SOURCE=main.c
typeset -g PYTHON_SOURCE=main.py
typeset -ga PYTHON_FLAGS=()
typeset -gA MODE_CPYTHON=(debug '-X dev -W default' extra '-X dev -W error' school '')
typeset -gA MODE_PYPY=(debug '-W default -X track-resources' extra '-W error -X track-resources' school '')
typeset -gA ACTION_DEST_DIR=(test-mult tests)
typeset -gA ACTION_SAVE_RELPATH=()
typeset -gA MODE_DEST_DIR=()
typeset -gA MODE_SAVE_RELPATH=()
typeset -g DEFAULT_TEST_FOLDER='{wsp-dir}/tests'
typeset -g NATIVE_FORMATTER=clang-format
typeset -g PYTHON_FORMATTER=ruff
typeset -g DEFAULT_REPORT_TESTS=all
typeset -g COMPANION_PORT=27122
typeset -g COMPANION_WAIT=120
typeset -g MINIMIZE_ATTEMPTS=200
typeset -g MINIMIZE_SECONDS=30
typeset -g MAX_FAILURES=10
typeset -g DEFAULT_LINE_LIMIT=10000
typeset -g DEFAULT_F_MODE=macro
typeset -g DEFAULT_MACRO=FILEO
typeset -g DEFAULT_WORKSPACE=.
typeset -ga EXTRA_WORKSPACES=()
typeset -g DEFAULT_DESTINATION=.
typeset -g DEFAULT_BRUTE=brute.cpp
typeset -g DEFAULT_GENERATOR=gen.cpp
typeset -g DEFAULT_ITERATIONS=1000
typeset -g DEFAULT_SEED=4
typeset -g TIME_KILL_FACTOR=2
typeset -g MEMORY_KILL_FACTOR=2
typeset -g DEFAULT_WARMUP=1
typeset -g DEFAULT_AVERAGE=1
typeset -g DEFAULT_TIME_UNIT=ms
typeset -g DEFAULT_MEMORY_UNIT=KiB
typeset -g MAX_LINE_BYTES=1048576
typeset -g MAX_CHECK_BYTES=67108864
typeset -g MAX_REPORT_BYTES=262144
typeset -g MAX_REPORT_LINES=10000
typeset -g MAX_SPOOL_BYTES=268435456
typeset -ga DEFAULT_FLAGS=(-O2)
typeset -ga WARNINGS_GCC=(-Wall -Wextra -Wshadow -Wconversion -Wduplicated-cond -Wlogical-op)
typeset -ga WARNINGS_CLANG=(-Wall -Wextra -Wshadow -Wconversion -Wlogical-op-parentheses -Wtautological-compare)
typeset -ga MODE_NAMES=(debug extra pragma pragma-fast pragma-native school)
typeset -gA MODE_KIND=(debug debug extra debug pragma flags pragma-fast flags pragma-native flags school flags)
typeset -gA MODE_CPU=(debug default extra default pragma default pragma-fast default pragma-native native school default)
typeset -gA MODE_FLAGS=(debug '-O2 -g2 -fsanitize=address,undefined -fsanitize=float-cast-overflow -fno-sanitize-recover=all -fno-omit-frame-pointer -DLOCAL' extra '-Og -g2 -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer -fno-optimize-sibling-calls -DLOCAL' pragma '-O3 -funroll-loops -Wunknown-pragmas' pragma-fast '-funroll-loops -fno-stack-protector -ffast-math -Wunknown-pragmas' pragma-native '-funroll-loops -fno-stack-protector -ffast-math -Wunknown-pragmas' school '')
typeset -gA MODE_GCC=(debug '' extra -fsanitize=float-cast-overflow,bounds-strict pragma-fast -Ofast pragma-native -Ofast school '-O2 -Wall -Werror -Wformat-security -Wignored-qualifiers -Winit-self -Wswitch-default -Wfloat-equal -Wpointer-arith -Wtype-limits -Wempty-body -Wno-logical-op -Wmissing-field-initializers -Wno-unused-result -lm -lm -std=gnu++17')
typeset -gA MODE_CLANG=(debug '' extra -fsanitize=float-cast-overflow,bounds pragma-fast -O3 pragma-native -O3 school '')
typeset -gA MODE_LIBSTDCXX=(debug -D_GLIBCXX_ASSERTIONS extra '-D_GLIBCXX_DEBUG -D_GLIBCXX_DEBUG_PEDANTIC' school '')
typeset -gA MODE_LIBCPP=(debug -D_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_FAST extra -D_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_DEBUG school '')
typeset -gA MODE_WARNINGS_GCC=(debug '' extra '-Wsign-conversion -Wnull-dereference -Wvla -Wfloat-equal -Wswitch-enum -Wformat=2 -Wpedantic -Wduplicated-branches -Warray-bounds=2' school '')
typeset -gA MODE_WARNINGS_CLANG=(debug '' extra '-Wsign-conversion -Wnull-dereference -Wvla -Wfloat-equal -Wswitch-enum -Wformat=2 -Wpedantic -Wunreachable-code -Warray-bounds' school '')
# CP_RUN_SETTINGS_END

typeset -gra SCHOOL_C_FLAGS=(-O2 -Wall -Werror -Wformat-security -Wignored-qualifiers -Winit-self -Wswitch-default -Wfloat-equal -Wpointer-arith -Wtype-limits -Wempty-body -Wno-logical-op -Wstrict-prototypes -Wold-style-declaration -Wold-style-definition -Wmissing-parameter-type -Wmissing-field-initializers -Wnested-externs -Wno-pointer-sign -Wno-unused-result -std=gnu99 -lm -lm)
typeset -gra SCHOOL_CPP_FLAGS=(-O2 -Wall -Werror -Wformat-security -Wignored-qualifiers -Winit-self -Wswitch-default -Wfloat-equal -Wpointer-arith -Wtype-limits -Wempty-body -Wno-logical-op -Wmissing-field-initializers -Wno-unused-result -lm -lm -std=gnu++17)


fail() { printf '%s: %s\n' "$PROGRAM" "$1" >&2; exit "${2:-2}"; }

compiler_operand() {
    case "$1" in
        -I|-isystem|-iquote|-idirafter|-include|-imacros|-isysroot|--sysroot|-target|--target|-arch|-resource-dir|-gcc-toolchain|--gcc-toolchain|--gcc-install-dir|-B|-D|-U|-stdlib++-isystem|-o|--output|-l|-L|-Xlinker|-MF|-MT|-MQ|-MJ|--std) return 0 ;;
        *) return 1 ;;
    esac
}


# Source: options.zsh
# Public operations are parsed before compiler options. All argv arrays retain
# original element boundaries; display quoting is never used for execution.
show_help() {
    cat <<'HELP'
Usage: cp-run [FILE] [OPTION]... [-- BACKEND-ARG... [-- PROGRAM-ARG...]]
       cp-run compile|debug[=PROFILE] [FILE] [OPTION]... [-- BACKEND-ARG...]
       cp-run debug[=PROFILE] run [FILE] [OPTION]... [-- BACKEND-ARG... [-- PROGRAM-ARG...]]
       cp-run run [TARGET] [OPTION]... [-- PROGRAM-ARG...]
       cp-run test[=auto|mult] [run] [CASE...] [FILE [IN [ANS [REPORT]]]] [OPTION]...
       cp-run stress [run] [MAIN [BRUTE [GEN]]] [OPTION]...
       cp-run companion [FILE] [OPTION]...
       cp-run pack[=in|ans] [IN-BUNDLE [ANS-BUNDLE]] [OPTION]...
       cp-run unpack[=in|ans] [IN-BUNDLE [ANS-BUNDLE]] [OPTION]...

Build, debug and check C++, C and Python with GCC, Clang, CPython or PyPy.
FILE is discovered locally; conventional sources are main.cpp/main.c/main.py.
Requires zsh 5.9; advanced features require Python 3.9+ (standard library only).

Commands:
  compile                 Prepare only; print the absolute launch-target path
  debug[=PROFILE]          Prepare with diagnostics only; add run to execute
  debug[=PROFILE] run      Prepare and run: debug or deeper extra profile
  run                     Run a native executable or Python source
  test[=auto|mult]         Whole input / separated cases / numbered file pairs
  stress                  Compare MAIN with BRUTE on inputs generated by GEN
  companion               Receive one problem from Competitive Companion
  pack[=in|ans]            Collect numbered tests into saved input/answer files
  unpack[=in|ans]          Restore those files into the chosen test folder
  configure               Edit defaults/profiles embedded in this script
  test run, stress run    Check existing targets without preparation
  tr, sr                  test run - / stress run -; reuse the last primary target
  --compile, --debug[=PROFILE], --run
                          Command aliases; first or after FILE (before --)
                          --debug --run prepares and runs; --debug alone never runs

Language and build:
  --compiler=NAME         GCC/gcc/g++ (default), clang/clang++; any position
  --interpreter-arg=ARG   Repeatable Python option (also preserves exact replay)
  --interpreter=NAME      User Python executable; default pypy3
  --language=NAME         Omitted-source preference: c++, c, python or auto
  -std=VALUE              Numeric/native C or C++ alias; newest advertised by default
  --profile=NAME          Saved debug/flags profile; pragma[-fast|-native] are native
  --no-w                  Omit generated baseline warnings
  -o PATH, -oPATH         Exact native output; overrides artifact routing
  -f, --file-io           Use saved file-I/O action; no =VALUE accepted
                          Factory macro: define FILEO (native only)
                          Auto in configure: redirect saved input/output files
                          Auto accepts optional IN [OUT] operands after -f
  format [--clang|--school] [FILE] [--check]  Format source and stop
  --review --annotate     Review findings; optionally annotate accepted warnings
  --report=FILE           Export formatter findings and decisions
  --strict-format[=MODE]  Require error-free formatting before compilation

Routing and checking:
  --wsp-dir=DIR           Workspace path; default ./; value is required
  --main-wsp[=DIR]        Use the first saved workspace, or a specified saved root
  --wsp-name=NAME         Search ancestors, or check an explicit workspace
  --dest-dir=DIR          Workspace-relative destination; action/profile configurable
  --save-relpath[=0|1]    Preserve artifact subtree; bare means 1
  --find=NAME             Find an omitted target under destination/subtree
  --test-f=DIR            Shared task folder; default {wsp-dir}/tests
                          Fixed filenames: in1.txt/ans1.txt, in2.txt/ans2.txt, ...
  --out=FILE              Program-output file for checks or saved-auto -f; default out.txt
  --sep=TEXT              Internal separator; default visible escape '\n\x1e\n'
  --bundle-format=FORMAT test=auto input: legacy (default) or counted
  --overwrite             Replace planned import/unpack files (default: refuse)
  --test-iters=N          Independent-case cap / stress count; whole-test time factor
  --report-tests=all|failed Show all payloads (default) or failed payloads only
  --cin, --cout           Test input framing / checking protocol on console
                          With -f and saved auto action: console stdin / stdout; choose only one
  --seed=N                Required-valued unsigned 64-bit stress seed; default 4
  --stop-on-failure       End stress at its first failed iteration
  --minimize[=STRATEGY]   Stress WA reduction: sequence (default), cases or lines
  --validator=PROGRAM    Extra input validation; required for cases/lines reduction
  --port=N, --wait=N      Companion port / wait seconds; defaults 27122 / 120

Measurements (program execution, excluding compilation):
  -t, --time              Show runtime; enable saved repetitions/warm-up
  -m, --memory            Show peak RSS; combine short flags as -ftm
  --warm-up[=0|1]         Hidden warm-up with -t/-m; saved default 1, bare means 1
  --average[=N]           Median time / maximum RSS across N runs; 0 means 1
  --time-unit=s|ms        Default ms
  --memory-unit=UNIT      B, KB, KiB, MB or MiB; default KiB
  --TLE=MS, --MLE=MiB     Nominal budgets; inf allowed; kill multipliers are editable
  --show-command          Display quoted commands on stderr, only when requested

Information and preferences:
  --doctor                Check required/optional tools without installing anything
  --export FILE / --import FILE   Back up or restore settings as JSON
  --help, --version       Show help / cp-run and compiler versions

Required values accept '=' or a separate operand: --wsp-dir DIR, -std 23.
-f has no mode operand: choose macro/auto in cp-run configure.
Required values cannot be empty. FILE - recalls source/target; ./- is literal.
File preferences/operands accept a literal {wsp-dir}/PATH workspace prefix.
Pack/unpack use saved input/answer filenames (factory in.txt/ans.txt) as bundles.
No selector: process both; one operand replaces IN, two replace IN and ANS.
=in or =ans: process only that stream, with at most one bundle operand.
Pack reads --test-f; unpack writes it. No source file or compiler is needed.
Unknown options go to the selected backend. Runtime tails remain opaque.
Python compile validates syntax and returns its source; it creates no fake binary.
Ordinary execution keeps direct stderr. Tests capture runtime stderr in reports;
compiler warnings/errors always remain live on the console. Stdout appears once
with repeated measurements. Every auto/mult test has its own TLE/MLE and metrics.

Documentation and bug reports: https://github.com/V1b3-C0d3r/cp-run
HELP
}

# Required values accept both GNU operand forms. Native compiler operands
# remain literal; wrapper values starting with a dash use the attached form.
take_value() {
    if [[ $arg == *=* ]]; then value=${arg#*=}
    else
        (( $# )) || fail "missing value for $arg"
        # Wrapper values starting with '-' must be attached. Native compiler
        # operands keep their literal spelling, even when they resemble flags.
        case "$arg" in
            --output|--std|--stdlib|--interpreter-arg) ;;
            --*) [[ $1 != -* ]] || fail "missing value for $arg; use ${arg}=VALUE for a value starting with '-'" ;;
        esac
        value=$1; consumed=1
    fi
    [[ -n $value ]] || fail "empty value for ${arg%%=*}"
}

select_profile() {
    local requested=$1
    [[ -n $requested && $requested != none ]] || fail 'provide a saved profile name'
    [[ $profile == none || $profile == "$requested" ]] || fail 'select only one profile'
    profile=$requested
}

# Keep aliases identical before/after FILE. Debug is a build operation; run
# combined with debug requests a source build followed by execution, not a binary.
select_operation_alias() {
    local option=$1 requested=${1#--} selected
    requested=${requested%%=*}
    case "$requested" in
        compile)
            [[ $action == ordinary || $action == compile ]] || fail "$option conflicts with the $action command"
            action=compile ;;
        debug)
            [[ $action == ordinary || $action == debug || $action == run ]] || fail "$option conflicts with the $action command"
            [[ $action != run ]] || debug_run=1
            action=debug; binary_mode=0
            selected=${option#--debug}; selected=${selected#=}
            select_profile "${selected:-debug}" ;;
        run)
            if [[ $action == debug ]]; then debug_run=1
            else
                [[ $action == ordinary || $action == run ]] || fail "$option conflicts with the $action command"
                action=run; binary_mode=1
            fi ;;
    esac
}

parse_cli() {
    local arg value consumed=0 slots=1 f_count=0
    local -a positionals=()

    # Shorthands insert only the primary FILE; the ordinary parser still owns
    # test data, stress roles and both compiler/runtime argument boundaries.
    case "${1-}" in
        tr) shift; set -- test run - "$@" ;;
        sr) shift; set -- stress run - "$@" ;;
    esac

    # Only the first word is a bare operation selector. Prefix a colliding
    # filename with './'; later filenames are never reinterpreted as commands.
    if (( $# )); then
        case "$1" in
            pack|pack=*|unpack|unpack=*)
                arg=$1; shift
                action=${arg%%=*}
                bundle_stream=both
                if [[ $arg == *=* ]]; then
                    bundle_stream=${arg#*=}
                    case "$bundle_stream" in in|ans) ;; *) fail 'pack/unpack accepts =in, =ans, or no selector for both' ;; esac
                fi ;;
            format)
                action=ordinary; prettier=format; shift
                if [[ ${1-} == stress ]]; then action=stress; shift; fi ;;
            compile|run|stress|companion|configure) action=$1; shift ;;
            debug|debug=*)
                action=debug; value=${1#debug}; value=${value#=}
                select_profile "${value:-debug}"; shift ;;
            test=mult) action=test; mult=1; shift ;;
            test|test=|test=auto) action=test; [[ $1 != test=auto ]] || auto=1; shift ;;
            test=*) fail 'test supports normal mode or test=auto; test=manual was removed' ;;
        esac
    fi
    # Consume combined prefix aliases before collecting FILE, so both
    # '--debug --run FILE' and 'FILE --debug --run' share one interpretation.
    while (( $# )); do
        case "$1" in
            --compile|--run|--debug|--debug=*) select_operation_alias "$1"; shift ;;
            *) break ;;
        esac
    done
    if [[ $action == debug ]] && (( $# )) && [[ $1 == run ]]; then debug_run=1; shift; fi
    if [[ $action == run ]]; then binary_mode=1; fi
    if [[ $action == test || $action == stress ]] && (( $# )) && [[ $1 == run ]]; then
        binary_mode=1; shift
    fi

    # Numbered case selectors occupy their own prefix, never source operands.
    if [[ $action == test ]] && (( auto || mult )); then
        while (( $# )) && [[ $1 == <-> || $1 == -<-> ]]; do cases+=("$1"); shift; done
    elif [[ $action == test ]] && (( $# )) && [[ $1 == <-> || $1 == -<-> ]]; then
        fail 'case numbers require test=auto; prefix a numeric filename with ./'
    fi
    case "$action" in test) slots=4 ;; stress) slots=3 ;; pack|unpack) slots=2; [[ $bundle_stream == both ]] || slots=1 ;; esac
    while (( $# && ${#positionals} < slots )) && { [[ $1 != -* ]] || { (( ! ${#positionals} )) && [[ $1 == - ]]; }; }; do
        positionals+=("$1"); shift
    done
    source_file=${positionals[1]-}
    positional_count=${#positionals}
    if [[ $action == pack || $action == unpack ]]; then
        if [[ $bundle_stream == ans ]]; then answer_file=${positionals[1]:-$answer_file}
        else
            input_file=${positionals[1]:-$input_file}
            [[ $bundle_stream != both ]] || answer_file=${positionals[2]:-$answer_file}
        fi
        source_file=
    elif [[ $action == test ]]; then
        [[ -z ${positionals[2]-} ]] || input_file=${positionals[2]}
        [[ -z ${positionals[3]-} ]] || answer_file=${positionals[3]}
        [[ -z ${positionals[4]-} ]] || report_file=${positionals[4]}
    elif [[ $action == stress ]]; then
        brute_file=${positionals[2]:-$DEFAULT_BRUTE}
        generator_file=${positionals[3]:-$DEFAULT_GENERATOR}
    fi

    while (( $# )); do
        arg=$1; shift; consumed=0
        case "$arg" in --file-io|--file-io=*) arg="-f${arg#--file-io}" ;; esac
        case "$arg" in
            --)
                managed_count=${#compiler_args}
                if (( binary_mode )); then runtime_args+=("$@"); return; fi
                if [[ $action == compile || $action == debug && $debug_run == 0 ]]; then compiler_args+=("$@"); return; fi
                while (( $# )) && [[ $1 != -- ]]; do compiler_args+=("$1"); shift; done
                if (( $# )); then shift; runtime_args+=("$@"); fi
                return ;;
            --help) help_requested=1 ;;
            --version) version_requested=1 ;;
            --compile|--run|--debug|--debug=*)
                select_operation_alias "$arg" ;;
            --set-default|--set-default=*|--set-defaults|--set-defaults=*) fail 'use cp-run configure' ;;
            --pack|--pack=*|--unpack|--unpack=*) fail 'use cp-run pack or cp-run unpack' ;;
            --export|--export=*|--import|--import=*|--export-settings|--export-settings=*|--import-settings|--import-settings=*)
                [[ -z $transfer_action ]] || fail 'select one settings transfer action'
                take_value "$@"; (( ! consumed )) || shift
                transfer_path=$value; transfer_action=${arg#--}; transfer_action=${transfer_action%%[-=]*} ;;
            --warm-up|--warm-up=*|--average|--average=*)
                measurement_controls=1
                if [[ $arg == *=* ]]; then value=${arg#*=}
                elif (( $# )) && [[ $1 == <-> || $1 == -<-> ]]; then value=$1; shift
                elif [[ $arg == --warm-up ]]; then value=1
                else value=$DEFAULT_AVERAGE; fi
                case "$arg" in
                    --warm-up*) [[ $value == 0 || $value == 1 ]] || fail '--warm-up accepts 0 or 1'; warmup=$value ;;
                    *) [[ $value == <-> && ${#value} -le 6 ]] && (( 10#$value <= 100000 )) || fail '--average accepts 0..100000'
                       average=$(( 10#$value )); (( average )) || average=1 ;;
                esac ;;
            --time-unit|--time-unit=*|--memory-unit|--memory-unit=*)
                take_value "$@"; (( ! consumed )) || shift
                case "$arg" in
                    --time-unit*) [[ $value == s || $value == ms ]] || fail '--time-unit accepts s or ms'; time_unit=$value ;;
                    *) case "$value" in B|KB|KiB|MB|MiB) memory_unit=$value ;; *) fail '--memory-unit accepts B, KB, KiB, MB or MiB' ;; esac ;;
                esac ;;
            --profile|--profile=*) take_value "$@"; (( ! consumed )) || shift; select_profile "$value" ;;
            --out|--out=*)
                take_value "$@"; (( ! consumed )) || shift
                result_file=$value; result_given=1 ;;
            --compiler|--compiler=*|--dest-dir|--dest-dir=*|--wsp-dir|--wsp-dir=*|--wsp-name|--wsp-name=*|--find|--find=*|--TLE|--TLE=*|--MLE|--MLE=*|--sep|--sep=*|--test-iters|--test-iters=*|--seed|--seed=*)
                take_value "$@"; (( ! consumed )) || shift
                case "$arg" in
                    --compiler*) compiler_choice=$value; compiler_given=1 ;;
                    --dest-dir*) destination=$value; destination_given=1 ;;
                    --wsp-dir*) workspace_dir=$value; dir_given=1 ;;
                    --wsp-name*) workspace_name=$value; name_given=1 ;;
                    --find*) find_name=$value ;;
                    --TLE*) timeout_ms=$value; timeout_given=1 ;;
                    --MLE*) memory_mib=$value; memory_given=1 ;;
                    --sep*) separator=$value; sep_given=1 ;;
                    --test-iters*) num_test=$value ;;
                    --seed*) seed=$value ;;
                esac ;;
            --main-wsp|--main-wsp=*)
                main_wsp_given=1; main_wsp=
                if [[ $arg == *=* ]]; then main_wsp=${arg#*=}
                elif (( $# )) && [[ $1 != -* ]]; then main_wsp=$1; shift
                fi ;;
            --save-relpath|--save-relpath=*)
                if [[ $arg == *=* ]]; then value=${arg#*=}
                elif (( $# )) && [[ $1 == 0 || $1 == 1 ]]; then value=$1; shift
                else value=1; fi
                [[ $value == 0 || $value == 1 ]] || fail "${arg%%=*} accepts 0 or 1"
                save_relpath=$value; relpath_given=1 ;;
            --minimize|--minimize=*)
                if [[ $arg == *=* ]]; then minimize=${arg#*=}
                elif (( $# )) && [[ $1 == sequence || $1 == lines || $1 == cases ]]; then minimize=$1; shift
                else minimize=sequence; fi
                case "$minimize" in sequence|lines|cases) ;; *) fail '--minimize accepts sequence, lines or cases' ;; esac ;;
            --validator|--validator=*) take_value "$@"; (( ! consumed )) || shift; validator=$value ;;
            --strict-format|--strict-format=*|--sctrict-format|--sctrict-format=*)
                strict_formatter=$FORMAT_MODE
                [[ $arg != *=* || -z ${arg#*=} ]] || strict_formatter=${arg#*=}
                case $strict_formatter in clang|school) ;; *) fail '--strict-format accepts clang or school' ;; esac ;;
            --no-cache) format_cache=0 ;;
            --review) review=1 ;;
            --annotate|--anotate) annotate=1; review=1 ;;
            --report|--report=*)
                take_value "$@"; (( ! consumed )) || shift; review_report=$value ;;
            --doctor) doctor_requested=1 ;;
            --clang|--school)
                [[ -n $prettier ]] || fail 'use format --clang or format --school'
                format_mode=${arg#--} ;;
            --check)
                [[ -n $prettier ]] || fail '--check requires format'
                prettier=check ;;
            --make-prettier|--make-prettier=*) fail "unknown option: $arg" ;;
            --port|--port=*|--wait|--wait=*)
                take_value "$@"; (( ! consumed )) || shift
                companion_controls=1
                if [[ $arg == --port* ]]; then companion_port=$value; else companion_wait=$value; fi ;;
            --overwrite) overwrite=1; data_controls=1 ;;
            --stop-on-failure) stop_on_failure=1 ;;
            --test-f|--test-f=*|--bundle-format|--bundle-format=*|--report-tests|--report-tests=*)
                take_value "$@"; (( ! consumed )) || shift
                case "$arg" in
                    --test-f*) test_folder=$value; layout_controls=1 ;;
                    --bundle-format*) [[ $value == legacy || $value == counted ]] || fail '--bundle-format accepts legacy or counted'; bundle_format=$value; bundle_given=1 ;;
                    --report-tests*) [[ $value == all || $value == failed ]] || fail '--report-tests accepts all or failed'; report_tests=$value; report_controls=1 ;;
                esac ;;
            --interpreter-arg|--interpreter-arg=*) take_value "$@"; (( ! consumed )) || shift; interpreter_args+=("$value") ;;
            --language|--language=*)
                take_value "$@"; (( ! consumed )) || shift
                case "$value" in c++|c|python|auto) language_choice=$value ;; *) fail '--language accepts c++, c, python or auto' ;; esac ;;
            --interpreter|--interpreter=*) take_value "$@"; (( ! consumed )) || shift; interpreter_choice=$value; interpreter_given=1 ;;

            --source|--source=*|--test-dir|--test-dir=*|--in-tmp|--in-tmp=*|--ans-tmp|--ans-tmp=*|--save-test-relpath|--save-test-relpath=*)
                fail 'test files use fixed inN.txt/ansN.txt names; select their folder with --test-f=DIR' ;;
            --text|--text-sep|--text-sep=*) fail 'use cp-run pack/unpack with --test-f=DIR; --sep selects the bundle delimiter' ;;
            --cph-ng|--cph-ng=*|--save-relpth|--save-relpth=*) fail 'use --save-relpath' ;;
            --workspace-name|--workspace-name=*) fail 'use --wsp-name=NAME' ;;
            --workspace-dir|--workspace-dir=*) fail 'use --wsp-dir=DIR' ;;
            --destination-dir|--destination-dir=*) fail 'use --dest-dir=DIR' ;;
            --timeout|--timeout=*) fail 'use --TLE=MS' ;;
            --memory-limit|--memory-limit=*) fail 'use --MLE=MiB' ;;
            --num-test|--num-test=*) fail 'use --test-iters=N' ;;
            --compile=*|--run=*|--no-w=*|--show-command=*|--cin=*|--cout=*|--time=*|--memory=*|--help=*|--version=*)
                fail "${arg%%=*} does not take a value" ;;
            --no-w) no_warnings=1 ;;
            --show-command) show_command=1 ;;
            --cin) console_in=1 ;;
            --cout) console_out=1 ;;
            --time) measure_time=1 ;;
            --memory) measure_memory=1 ;;
            -[ftm]##|-[ftm]##=*)
                # Recognize only whole f/t/m clusters. Native -fopenmp and
                # other compiler flags stay opaque, including attached values.
                [[ $arg != *=* ]] || fail '-f/-t/-m take no values; choose the -f action in cp-run configure'
                [[ $arg != *t* ]] || measure_time=1
                [[ $arg != *m* ]] || measure_memory=1
                if [[ $arg == *f* ]]; then
                    [[ $arg != *f*f* ]] || fail 'use -f only once'
                    (( ++f_count == 1 )) || fail 'use -f only once'
                    f_mode=$DEFAULT_F_MODE
                    # Optional filenames belong to saved auto mode, never a
                    # mode selector. -- or another flag ends their operands.
                    if [[ $f_mode == auto ]]; then
                        if (( $# )) && [[ $1 != -* ]]; then input_file=$1; shift; fi
                        if (( $# )) && [[ $1 != -* ]]; then result_file=$1; shift; fi
                    fi
                fi ;;
            -o|--output|--output=*) take_value "$@"; (( ! consumed )) || shift; output=$value; output_given=1 ;;
            -o?*) output=${arg#-o}; output_given=1 ;;
            -std|-std=*|--std|--std=*)
                take_value "$@"; (( ! consumed )) || shift
                compiler_args+=("-std=$value"); managed_standards+=("$value"); std_seen=1 ;;
            -ansi|--ansi) compiler_args+=("$arg"); std_seen=1 ;;
            -stdlib|--stdlib|-stdlib=*|--stdlib=*)
                take_value "$@"; (( ! consumed )) || shift; compiler_args+=("-stdlib=$value") ;;
            --no-run) fail '--no-run was replaced by the compile command' ;;
            --debug-flags|--extra-debug-flags|--mode|--mode=*) fail 'use debug, debug=extra or --profile=NAME' ;;
            --test|--run-file|--run-file=*|--run-args|--run-arg=*) fail 'use test/run commands and -- argument boundaries; see --help' ;;
            -)
                if [[ -n $prettier && -z $source_file ]]; then source_file=-
                else compiler_args+=("$arg"); fi ;;
            -*)
                compiler_args+=("$arg")
                if compiler_operand "$arg" && (( $# )); then compiler_args+=("$1"); shift; fi ;;
            *)
                if [[ -n $prettier && -z $source_file ]]; then
                    source_file=$arg; positional_count=1; continue
                fi
                fail "unexpected argument: $arg; put program arguments after --" ;;
        esac
    done
    managed_count=${#compiler_args}
}


# Source: paths.zsh
# Resolve workspace routing once, for compilation or run --find.
# An explicit binary path skips this branch just like an explicit -o path.
resolve_workspace_root() {
    [[ -z $workspace ]] || return 0
    local requested
    if (( name_given )); then
        case "$workspace_name" in ''|.|..|*/*) fail 'workspace name must be one nonempty directory name' ;; esac
    fi
    if (( main_wsp_given )) && [[ -z $main_wsp ]]; then
        [[ -d $DEFAULT_WORKSPACE && -x $DEFAULT_WORKSPACE ]] || fail "workspace directory is not accessible: $DEFAULT_WORKSPACE" 1
        workspace=${DEFAULT_WORKSPACE:P}
    elif (( main_wsp_given || ${#EXTRA_WORKSPACES} && ! dir_given && ! name_given )); then
        local root ancestor
        local -a roots=("$DEFAULT_WORKSPACE" "${EXTRA_WORKSPACES[@]}") available=()
        for root in "${roots[@]}"; do
            [[ -d $root && -x $root ]] && available+=("${root:P}")
        done
        if (( main_wsp_given )); then
            requested=$main_wsp
            [[ -d $requested && -x $requested ]] || fail "workspace directory is not accessible: $requested" 1
            workspace=${requested:P}
            (( ${available[(Ie)$workspace]} )) || fail "workspace is not in the saved list: $requested"
        else
            ancestor=${cwd:A}
            if [[ -n $source_file && $source_file != - && $source_file != *'{wsp-dir}'* ]]; then
                ancestor=${source_file:h:P}
            fi
            while ! (( ${available[(Ie)$ancestor]} )); do
                [[ $ancestor != / ]] || fail 'no saved workspace contains this file or directory; use --main-wsp' 1
                ancestor=${ancestor:h}
            done
            workspace=$ancestor
        fi
    elif (( dir_given || ! name_given )); then
        requested=$workspace_dir
        case "$requested" in
            .|./|"$cwd"|"$cwd"/) workspace=${cwd:A} ;;
            *)
                if [[ $requested != /* ]]; then requested="$cwd/$requested"; fi
                workspace=$(cd -q -P -- "$requested" 2>/dev/null && pwd -P) ||
                    fail "workspace directory is not accessible: $requested" 1 ;;
        esac
        if (( name_given )) && [[ ${workspace:t} != "$workspace_name" ]]; then
            fail "workspace name '$workspace_name' does not match directory '${workspace:t}'"
        fi
    else
        workspace=${cwd:A}
        while [[ ${workspace:t} != "$workspace_name" ]]; do
            [[ $workspace != / ]] || fail "workspace folder not found: $workspace_name" 1
            workspace=${workspace:h}
        done
    fi
    workspace_prefix="${workspace%/}/" # Exactly one separator, also for '/'.
}

resolve_workspace() {
    resolve_workspace_root
    case "$destination" in
        '{wsp-dir}') destination=. ;;
        '{wsp-dir}/'*) destination=${destination#'{wsp-dir}/'} ;;
    esac
    [[ -n $destination && $destination != /* ]] || fail 'destination must be a nonempty relative path'
    case "/$destination/" in */../*) fail 'destination must not contain .. components' ;; esac
    output_dir="$workspace_prefix$destination"
}

# Expand only an explicit workspace prefix. Resolving the root separately
# keeps -o's destination bypass intact when an input uses a workspace anchor.
workspace_file_path() {
    value=$1
    [[ $value == *'{wsp-dir}'* ]] || return 0
    local relative candidate
    case "$value" in
        '{wsp-dir}/'*) relative=${value#'{wsp-dir}/'} ;;
        *) fail 'use {wsp-dir}/PATH at the beginning of a file path' ;;
    esac
    [[ -n $relative && $relative != /* && $relative != *'{wsp-dir}'* ]] || fail 'invalid workspace file path'
    case "/$relative/" in */../*) fail 'workspace file path must not contain .. components' ;; esac
    resolve_workspace_root
    candidate="${workspace%/}/$relative"
    case "${candidate:A}" in
        "$workspace"|"$workspace_prefix"*) value=$candidate ;;
        *) fail 'workspace file path escapes workspace through a symbolic link' ;;
    esac
}

# Resolve physical existing directories with cd/pwd. Lexical ':a' reduction
# alone is insufficient when '..' follows a symlink. No GNU realpath is needed.
resolve_output() {
    local requested source_dir name ancestor
    if [[ $source_file != /* ]]; then source_file="$cwd/$source_file"; fi
    [[ -f $source_file && -r $source_file ]] || fail "input is not a readable regular file: $source_file" 1

    if (( ! output_given )); then
        resolve_workspace
        if (( save_relpath )); then
            source_dir=${source_file:h}
            case "$source_dir" in
                "$cwd") ;;
                "$workspace") ;;
                *) source_dir=$(cd -q -P -- "$source_dir" 2>/dev/null && pwd -P) || fail 'cannot resolve source directory' 1 ;;
            esac
            case "$source_dir" in
                "$workspace") ;;
                "$workspace_prefix"*) output_dir+="/${source_dir#"$workspace_prefix"}" ;;
                *) fail '--save-relpath requires a source inside the workspace' 1 ;;
            esac
        fi
        name=${source_file:t}
        output="$output_dir/${name%.*}.out" # Remove only the last extension.
    fi

    # Explicit -o reaches this point without reading workspace/destination
    # semantics at all. Its relative paths start at the invocation directory.
    [[ -n $output ]] || fail 'output filename must not be empty'
    if [[ $output != /* ]]; then output="$cwd/$output"; fi
    [[ ! -d $output ]] || fail "output is a directory: $output" 1
    # :t/:h discard trailing slashes. Reject directory-shaped paths before
    # using those modifiers, including parents that do not exist yet.
    case "$output" in */|*/.|*/..) fail 'output must name a file, not a directory path' ;; esac
    [[ ! $output -ef $source_file ]] || fail 'output must not overwrite the input file'
    output_name=${output:t}; output_dir=${output:h}
    [[ -n $output_name ]] || fail 'output filename must not be empty'
    if (( ! output_given )) && [[ -L $output ]]; then
        fail 'automatic output must not be a symbolic link; use -o for an explicit path' 1
    fi

    # Check before mkdir: an existing directory symlink must not create new
    # directories outside the workspace. This is not a concurrent-write lock.
    ancestor=$output_dir
    while [[ ! -e $ancestor && ! -L $ancestor ]]; do ancestor=${ancestor:h}; done
    case "$ancestor" in
        "$cwd"|"$workspace") ;;
        *) ancestor=$(cd -q -P -- "$ancestor" 2>/dev/null && pwd -P) || fail 'output ancestor is not an accessible directory' 1 ;;
    esac
    if (( ! output_given )); then
        case "$ancestor" in "$workspace"|"$workspace_prefix"*) ;; *) fail 'destination escapes the workspace' 1 ;; esac
    fi
    [[ ! -d $output_dir ]] || output_dir=$ancestor
}

# Direct paths do no workspace work. Lookup checks two exact names, with one
# optional lowercase .out suffix; ambiguity never depends on directory order.
resolve_binary() {
    local requested=$1 name directory candidate
    local -a found=() names=()
    if [[ -n $requested ]]; then
        [[ $requested == /* ]] || requested="$cwd/$requested"
    else
        [[ -n $find_name ]] || fail 'provide a binary path or --find=NAME'
        case "$find_name" in .|..|*/*) fail '--find requires one filename component' ;; esac
        resolve_workspace
        if (( save_relpath )); then
            case "$cwd" in
                "$workspace") ;;
                "$workspace_prefix"*) output_dir+="/${cwd#"$workspace_prefix"}" ;;
                *) fail '--save-relpath requires the run directory to be inside the workspace' 1 ;;
            esac
        fi
        directory=$(cd -q -P -- "$output_dir" 2>/dev/null && pwd -P) || fail 'binary directory is not accessible' 1
        case "$directory" in "$workspace"|"$workspace_prefix"*) ;; *) fail 'destination escapes the workspace' 1 ;; esac
        if [[ $find_name == *.out ]]; then names=("${find_name%.out}" "$find_name")
        else names=("$find_name" "$find_name.out"); fi
        for name in "${names[@]}"; do
            candidate="$directory/$name"
            if [[ -f $candidate && ( -x $candidate || $candidate == *.py && -r $candidate ) ]]; then found+=("$candidate"); fi
        done
        (( ${#found} )) || fail "binary not found: $find_name" 1
        (( ${#found} == 1 )) || fail "ambiguous binary: $find_name; provide an explicit path"
        requested=${found[1]}
    fi
    [[ -f $requested ]] || fail "binary not found: $requested" 1
    [[ $requested == *.py && -r $requested || -x $requested ]] || fail "binary is not executable: $requested" 126
    resolved_binary=$requested
}

# Resolve plans before probing compilers or touching test data. The compiler
# helpers use zsh's dynamic local scope; their arrays never leak between roles.
# Omitted source selection is nonrecursive and uses regular files only.
select_source() {
    local preferred=$language_choice fallback candidate
    local -a sources=() fallbacks=()
    case "$preferred" in
        c++) sources=(./*.(cpp|cc|cxx|C)(N-.)); fallback=$DEFAULT_SOURCE ;;
        c) sources=(./*.c(N-.)); fallback=$C_SOURCE ;;
        python) sources=(./*.py(N-.)); fallback=$PYTHON_SOURCE ;;
        auto) fallback= ;;
    esac
    if (( ${#sources} == 1 )); then source_file=${sources[1]#./}; return; fi
    if [[ -n $fallback ]]; then
        workspace_file_path "$fallback"; fallback=$value
        if [[ -f $fallback ]]; then source_file=$fallback; return; fi
    fi
    (( ! ${#sources} )) || fail "cannot select $preferred source: provide FILE or create $fallback"
    # With no preferred-language source, accept a unique other-language source
    # or a unique conventional fallback. Never resolve ambiguity by glob order.
    sources=(./*.(cpp|cc|cxx|C|c|py)(N-.))
    if (( ${#sources} == 1 )); then source_file=${sources[1]#./}; return; fi
    for candidate in "$DEFAULT_SOURCE" "$C_SOURCE" "$PYTHON_SOURCE"; do
        workspace_file_path "$candidate"; candidate=$value
        [[ ! -f $candidate ]] || fallbacks+=("$candidate")
    done
    if (( ${#fallbacks} == 1 )); then source_file=${fallbacks[1]}; return; fi
    fail "cannot select a source: provide FILE (found ${#sources} supported files)"
}

# Source: languages.zsh
# Languages produce argv, not command strings. The internal service Python is
# deliberately independent from the interpreter used to run a user's source.
source_language() {
    case "$1" in
        *.py) language=python ;;
        *.c) language=c ;;
        *) language=c++ ;;
    esac
}

resolve_interpreter() {
    local requested=$interpreter_choice
    interpreter=$(whence -p -- "$requested" 2>/dev/null) || fail "interpreter not found: $requested" 127
    interpreter=${interpreter:A}
}

# Audit only source ownership and diagnostic promises. Other options remain
# literal backend argv. Python short clusters must not hide -O or -Wignore.
audit_python_options() {
    local guarded=$1 floor=$2 word letters letter parameter action index=1
    shift 2
    local -a words=("$@")
    while (( index <= ${#words} )); do
        word=${words[index]}; (( ++index ))
        case "$word" in
            -|--|--help|--version|--info) fail "interpreter option replaces source execution: $word" ;;
            --jit|--check-hash-based-pycs)
                (( index <= ${#words} )) || fail "missing Python operand for $word"
                (( ++index )); continue ;;
            --*) continue ;; # Unknown long switches remain the interpreter's decision.
            -?*) letters=${word#-} ;;
            *) fail "interpreter operand replaces FILE: $word; put program arguments after the runtime boundary" ;;
        esac
        while [[ -n $letters ]]; do
            letter=${letters[1]}; letters=${letters[2,-1]}
            case "$letter" in
                c|m|h|V|i|'?') fail "interpreter option replaces source execution: $word" ;;
                O) (( ! guarded )) || fail "debug profile conflicts with $word" ;;
                W|X)
                    parameter=$letters; letters=
                    if [[ -z $parameter ]]; then
                        (( index <= ${#words} )) || fail "missing Python operand for $word"
                        parameter=${words[index]}; (( ++index ))
                    fi
                    if [[ $letter == W ]] && (( guarded )); then
                        action=${parameter%%:*}; action=${action//[[:space:]]/}
                        # Python accepts abbreviated actions (-Wi, -We). Keep
                        # only filters at least as visible as the profile floor.
                        case "$action" in
                            e|er|err|erro|error) ;;
                            ''|d|de|def|defa|defau|defaul|default|a|al|all|alw|alwa|alway|always)
                                [[ $floor != error ]] || fail "debug profile conflicts with Python warning filter: $parameter" ;;
                            *) fail "debug profile conflicts with Python warning filter: $parameter" ;;
                        esac
                    fi ;;
                b|B|d|E|I|P|q|R|s|S|u|U|v) ;;
                *) break ;; # An invalid switch is diagnosed by Python, unchanged.
            esac
        done
    done
}

python_launch() {
    local selected=$1 selected_profile=$2 text= implementation= python_version= floor=default word index
    local -a extra=("${interpreter_args[@]}") profile_options=()
    resolve_interpreter
    launch_args=("$interpreter" "${PYTHON_FLAGS[@]}")
    # A native primary's compiler tail never reaches an interpreted role.
    if [[ $primary_language == python ]]; then extra+=("${compiler_args[@]}"); fi
    if [[ $selected_profile != none ]]; then
        # Query only requested profiles. The running interpreter reports its
        # implementation and version; executable names are not reliable evidence.
        value=$("$interpreter" -c 'import platform,sys; print(platform.python_implementation()); print("%d.%d" % sys.version_info[:2])') || return $?
        implementation=${value%%$'\n'*}; python_version=${value#*$'\n'}
        case "$implementation" in
            CPython) text=${MODE_CPYTHON[$selected_profile]-} ;;
            PyPy) text=${MODE_PYPY[$selected_profile]-} ;;
        esac
        [[ -n $text ]] || fail "profile '$selected_profile' has no $implementation configuration"
        # CPython development mode was introduced in 3.7. Built-in PyPy
        # profiles use Python 3 diagnostics, not CPython-only -X dev.
        case "$implementation:$python_version" in
            CPython:3.[0-6]|CPython:2.*|PyPy:2.*)
                fail "profile '$selected_profile' requires Python 3.7+ diagnostics; selected $implementation $python_version" ;;
        esac
        profile_options=("${(@Q)${(z)text}}")
        launch_args+=("${profile_options[@]}")
        if [[ ${MODE_KIND[$selected_profile]} == debug ]]; then
            (( ! no_warnings )) || fail 'debug profile conflicts with --no-w'
            [[ ${PYTHONOPTIMIZE:-0} == 0 ]] || fail 'debug profile conflicts with PYTHONOPTIMIZE'
            for (( index=1; index<=${#profile_options}; ++index )); do
                word=${profile_options[index]}
                if [[ $word == -Werror* || $word == -W && ${profile_options[index+1]-} == error* ]]; then floor=error; fi
            done
            audit_python_options 1 "$floor" "${PYTHON_FLAGS[@]}" "${extra[@]}"
        fi
    fi
    audit_python_options 0 default "${launch_args[@]:1}" "${extra[@]}"
    launch_args+=("${extra[@]}" "$selected")
}

# Counted per-role argv travels through the existing bridge without JSON or
# shell evaluation. Native and interpreted roles share exactly the same runner.
record_launch() {
    local label=$1 index
    config[launch_${label}_count]=${#launch_args}
    for (( index=1; index<=${#launch_args}; ++index )); do
        config[launch_${label}_${index}]=${launch_args[index]}
    done
}

# Route each setting independently. Unset map entries inherit; '0' disables a
# saved boolean. Test submodes inherit the named test command before globals.
resolve_action_defaults() {
    local key=$action base=$action parent=$action
    if [[ $action == pack || $action == unpack || $action == companion ]]; then base=test-mult; parent=test; fi
    if [[ $action == test ]]; then
        (( ! auto )) || key=test-auto
        (( ! mult )) || key=test-mult
    fi
    if (( ! destination_given )); then
        destination=${MODE_DEST_DIR[$profile]-${ACTION_DEST_DIR[$key]-${ACTION_DEST_DIR[$base]-${ACTION_DEST_DIR[$parent]-$DEFAULT_DESTINATION}}}}
    fi
    if (( ! relpath_given )); then save_relpath=${MODE_SAVE_RELPATH[$profile]-${ACTION_SAVE_RELPATH[$key]-${ACTION_SAVE_RELPATH[$base]-${ACTION_SAVE_RELPATH[$parent]-0}}}}; fi
}

# Omitted stress roles use a conventional stem, preferring the main language.
# An explicit saved filename still wins when it exists.
discover_role() {
    local requested=$1 stem=$2 preferred suffix
    workspace_file_path "$requested"; requested=$value
    if [[ -f $requested ]]; then value=$requested; return; fi
    case "$primary_language" in c) suffix=c ;; python) suffix=py ;; *) suffix=cpp ;; esac
    preferred="$stem.$suffix"
    if [[ -f $preferred ]]; then value=$preferred; return; fi
    local -a candidates=(./${stem}.(cpp|cc|cxx|C|c|py)(N-.))
    (( ${#candidates} == 1 )) || fail "provide $stem source: expected one conventional $stem file"
    value=${candidates[1]#./}
}

# Source: toolchain.zsh
identify_compiler() {
    local banner
    banner=$("$1" --version) || return 1
    compiler_banner=$banner          # Reused in a stress failure manifest.
    case "$banner" in
        *clang*|*Clang*) detected_family=clang ;;
        *GCC*|*'Free Software Foundation'*) detected_family=gcc ;;
        *) return 1 ;;
    esac
}

resolve_compiler() {
    local candidate directory major best=-1 best_path= detected_family= driver=g++ chosen=${CXX:-}
    if [[ $language == c ]]; then driver=gcc; chosen=${CC:-}; fi
    if [[ -n $chosen ]]; then
        compiler=$chosen               # One executable; flags belong in argv.
    elif [[ $family == clang ]]; then
        compiler=clang++; [[ $language != c ]] || compiler=clang
    else
        candidate=$(whence -p -- "$driver" 2>/dev/null)
        if [[ -n $candidate ]] && identify_compiler "$candidate" && [[ $detected_family == gcc ]]; then
            compiler=$candidate; return
        fi
        # Native path is an array tied to PATH. Read it; never use 'path' as
        # a scratch variable. (N) makes an unmatched driver glob an empty list.
        for directory in "${path[@]}"; do
            directory=${directory:-.}
            for candidate in "$directory"/${driver}-<->(N); do
                [[ -f $candidate && -x $candidate ]] || continue
                major=${candidate:t}; major=${major#${driver}-}; major=${major##0#}; major=${major:-0}
                (( ${#major} <= 3 )) || continue
                if (( major > best )) && identify_compiler "$candidate" && [[ $detected_family == gcc ]]; then
                    best=$major; best_path=$candidate
                fi
            done
        done
        [[ -n $best_path ]] || fail "GNU $driver not found; set CC/CXX or select --compiler=clang" 127
        compiler=$best_path; return
    fi
    candidate=$(whence -p -- "$compiler" 2>/dev/null) || fail "compiler not found: $compiler" 127
    compiler=$candidate
    identify_compiler "$compiler" || fail "cannot identify compiler: $compiler" 1
    [[ $detected_family == "$family" ]] || fail "compiler family mismatch: requested $family, $compiler reports $detected_family"
}

# Ask the driver for its vocabulary instead of assuming a release number.
# GCC lists options on stdout; Clang lists valid standards in the diagnostic
# for an intentionally invalid value. Only this private probe captures fd 2.
discover_standards() {
    (( ! ${#supported_standards} )) || return 0
    local listing line candidate
    if [[ $family == gcc ]]; then
        listing=$(LC_ALL=C "$compiler" --help="$language") || fail 'cannot query compiler standards' 1
    else
        listing=$(LC_ALL=C "$compiler" -std=__cp_run_probe__ -fsyntax-only -x "$language" /dev/null 2>&1)
    fi
    # Work per line: removing a wildcard prefix from a 60 KiB GCC help
    # listing is needlessly expensive in zsh. Each small line scans once.
    for line in "${(@f)listing}"; do
        local expression='(^|[^[:alnum:]_+])((gnu|c)[+][+][[:alnum:]]+)'
        if [[ $language == c ]]; then expression='(^|[^[:alnum:]_+])((gnu|c)(89|90|99|9x|11|1x|17|18|23|2x|2y)|iso9899:[0-9]+)'; fi
        while [[ $line =~ $expression ]]; do
            candidate=$match[2]
            line=${line#*"$candidate"}
            supported_standards+=("$candidate")
        done
    done
    (( ${#supported_standards} )) || fail 'cannot discover supported language standards' 1
}

validate_standards() {
    discover_standards
    local standard
    for standard in "${managed_standards[@]}"; do
        (( ${supported_standards[(Ie)$standard]} )) || fail "unsupported ${language:u} standard '$standard' for $compiler; supported: ${(j:, :)supported_standards}"
    done
}

detect_standard() {
    local candidate suffix year ordinal best=-1 selected=
    if [[ -n $auto_standard ]]; then flags+=("-std=$auto_standard"); return; fi
    discover_standards
    for candidate in "${supported_standards[@]}"; do
            if [[ $language == c ]]; then
                [[ $candidate == c[0-9]* ]] || continue
                suffix=${candidate#c}
            else
                [[ $candidate == c++* ]] || continue
                suffix=${candidate#c++}
            fi
            case "$suffix" in
                89) year=1989 ;; 90) year=1990 ;; 99|9x) year=1999 ;; 1x) year=2011 ;; 2x) year=2023 ;; 2y) if [[ $language == c ]]; then year=2029; else year=2014; fi ;;
                98) year=1998 ;; 03) year=2003 ;; 0x) year=2011 ;;
                1y) year=2014 ;; 1z) year=2017 ;;
                [0-9][0-9]) year=$(( 2000 + 10#${suffix} )) ;;
                [2-9][a-z])
                    printf -v ordinal '%d' "'${suffix[2]}"
                    year=$(( 2000 + 10 * suffix[1] + 3 * (ordinal - 97) )) ;;
                *) continue ;;
            esac
            # Prefer the final numeric spelling over its equal-ranked draft alias.
            if (( year > best )) || { (( year == best )) && [[ $suffix == [0-9][0-9] ]]; }; then
                best=$year; selected=$candidate
            fi
    done
    [[ -n $selected ]] || fail 'cannot discover supported language standards; specify -std=VALUE' 1
    auto_standard=$selected          # Stress builds share one compiler/configuration.
    flags+=("-std=$selected")
}

# Probe the selected C++ headers, not the driver brand. Carry options that
# select headers/targets/macros, including their separate operands. Linker
# options and source operands do not belong in this small preprocessor query.
detect_library() {
    local arg index library_macros mode
    local -a probe_args=()
    for (( index=1; index<=${#compiler_args}; ++index )); do
        arg=${compiler_args[index]}
        case "$arg" in
            -I|-isystem|-iquote|-idirafter|-include|-imacros|-isysroot|--sysroot|-target|--target|-arch|-resource-dir|-gcc-toolchain|--gcc-toolchain|--gcc-install-dir|-B|-D|-U|-stdlib++-isystem|--std)
                probe_args+=("$arg")
                if (( index < ${#compiler_args} )); then (( ++index )); probe_args+=("${compiler_args[index]}"); fi ;;
            -std=*|-stdlib=*|-I?*|-D?*|-U?*|-B?*|-isystem?*|-iquote?*|-idirafter?*|-isysroot?*|--sysroot=*|--target=*|-target=*|-resource-dir=*|--gcc-toolchain=*|--gcc-install-dir=*|-nostdinc|-nostdinc++|-m32|-m64|-ansi|--ansi)
                probe_args+=("$arg") ;;
        esac
    done
    library_macros=$(printf '#include <cstddef>\n' |
        "$compiler" "${flags[@]}" "${probe_args[@]}" -dM -E -x c++ -) || return $?
    if [[ $library_macros == *'#define __GLIBCXX__ '* ]]; then
        append_flags "${MODE_LIBSTDCXX[$profile]-}"
    elif [[ $library_macros == *'#define _LIBCPP_VERSION '* ]]; then
        # Require the feature actually selected in the editable profile.
        for mode in FAST DEBUG EXTENSIVE; do
            if [[ ${MODE_LIBCPP[$profile]-} == *"_LIBCPP_HARDENING_MODE_$mode"* ]]; then
                [[ $library_macros == *"#define _LIBCPP_HARDENING_MODE_$mode "* ]] ||
                    fail "selected libc++ does not provide $mode hardening" 1
            fi
        done
        append_flags "${MODE_LIBCPP[$profile]-}"
    else
        fail 'this mode requires identifiable libstdc++ or libc++ headers' 1
    fi
}

# A raw compiler tail remains opaque in ordinary builds. A diagnostic profile
# additionally rejects known ways to silently weaken its checks. We inspect
# tokens, not response-file contents or arbitrary compiler configuration files.
audit_profile() {
    local arg value proposed index macro
    local baseline_opt=$opt_rank baseline_debug=$debug_level
    for (( index=1; index<=${#compiler_args}; ++index )); do
        arg=${compiler_args[index]}
        case "$arg" in
            -fno-sanitize-recover*) ;; # Stopping sooner does not weaken diagnostics.
            -w|--no-warnings|-Wno-everything|-fno-sanitize*|-fsanitize-recover*|-fomit-frame-pointer|-ffast-math|-ffinite-math-only|-fsanitize-address-use-after-return=never)
                fail "debug profile conflicts with $arg" ;;
            -foptimize-sibling-calls)
                (( ${flags[(Ie)-fno-optimize-sibling-calls]} == 0 )) || fail "debug profile conflicts with $arg" ;;
            @*) fail 'response files cannot be audited in a debug profile; expand their arguments' ;;
            -Xclang|-Xpreprocessor|-mllvm|-Wp,*|-fsanitize-ignorelist=*|-fsanitize-blacklist=*|-fsanitize-system-ignorelist=*)
                fail "debug profile cannot audit forwarded or excluded checks: $arg" ;;
        esac
        if [[ $arg != -D && $arg != -U ]] && compiler_operand "$arg"; then
            (( ++index )); continue # A known operand is not another option.
        fi
        macro=
        if [[ $arg == -D || $arg == -U ]]; then
            (( ++index ))
            if (( index <= ${#compiler_args} )); then macro=${compiler_args[index]}; fi
        elif [[ $arg == -D?* || $arg == -U?* ]]; then macro=${arg[3,-1]}; fi
        case "${macro%%=*}" in
            LOCAL|NDEBUG|_GLIBCXX_ASSERTIONS|_GLIBCXX_DEBUG|_GLIBCXX_DEBUG_PEDANTIC|_LIBCPP_HARDENING_MODE|_LIBCPP_ENABLE_ASSERTIONS)
                fail "debug profile reserves macro ${macro%%=*}" ;;
        esac
        [[ $arg != -D && $arg != -U ]] || continue
        # Every explicit compiler region is guarded, not only the raw tail.
        case "$arg" in
            -O*|--optimize|--optimize=*)
                case "$arg" in -O*) value=${arg#-O} ;; --optimize) value=1 ;; *) value=${arg#*=} ;; esac
                if [[ -z $value ]]; then value=1; fi
                if [[ $value == <-> ]]; then value=${value##0#}; value=${value:-0}; fi
                case "$value" in
                    0) proposed=4 ;; g) proposed=3 ;; 1) proposed=2 ;; 2) proposed=1 ;;
                    <->|s|z|fast) proposed=0 ;; *) continue ;;
                esac
                (( proposed >= baseline_opt )) || fail "debug profile would be weakened by tail option $arg"
                if (( proposed > opt_rank )); then opt_rank=$proposed; fi ;;
            -g|-g<->|-ggdb|-ggdb<->|--debug|--debug=*|-gline-tables-only|-gline-directives-only|-gmlt)
                case "$arg" in
                    -g|--debug|-ggdb) value=2 ;;
                    --debug=*) value=${arg#*=} ;; -ggdb*) value=${arg#-ggdb} ;;
                    -gline*|-gmlt) value=1 ;; *) value=${arg#-g} ;;
                esac
                [[ $value == <-> ]] || continue
                value=${value##0#}; value=${value:-0}
                (( ${#value} <= 2 )) || continue
                (( 10#$value >= baseline_debug )) || fail "debug profile would be weakened by tail option $arg"
                if [[ $value == 3 ]]; then debug_level=3; fi ;;
        esac
    done
}


# Source: profiles.zsh
# Native shell-word parsing removes quoting without evaluating substitutions.
# Stored settings are generated with POSIX quoting by the interactive editor.
append_flags() {
    local text=$1
    [[ -n $text ]] || return 0
    local -a words=( "${(@Q)${(z)text}}" )
    flags+=("${words[@]}")
}

# CPU options are chosen by the real driver, never by the standard library.
# Ordinary/portable profiles take this branch without starting another process.
append_native_cpu() {
    local arg index triple candidate
    local -a options=("${flags[@]}" "${compiler_args[@]}")
    case "${MODE_CPU[$profile]-default}" in
        default) return 0 ;;
        native) ;;
        *) fail 'invalid saved CPU policy; use cp-run configure' ;;
    esac
    # Explicit target selection wins. Opaque forwarding can also hide a target;
    # do not expand it or guess. Skip known operands so -I -march=folder is data.
    for (( index=1; index<=${#options}; ++index )); do
        arg=${options[index]}
        case "$arg" in
            -m*|-target|--target|-target=*|--target=*|-arch|-arch=*|@*|-X*|-Wp,*|-Wa,*|-Wl,*|-specs*|--specs*|--config*|-fplugin*) return 0 ;;
        esac
        if compiler_operand "$arg"; then (( ++index )); fi
    done
    triple=$("$compiler" -dumpmachine 2>/dev/null) || return 0
    case "${triple:l}" in
        x86_64*|amd64*|i[3-6]86*) candidate=-march=native ;;
        aarch64*|arm64*|arm*|powerpc*|ppc*) candidate=-mcpu=native ;;
        *) return 0 ;; # Unknown backends retain their selected baseline ISA.
    esac
    # Generate an empty translation unit: accepting an option without running
    # the backend is insufficient. Failure only omits optional native tuning;
    # diagnostics/status from the actual user compilation still pass through.
    if "$compiler" "$candidate" -Werror -x "$language" -S /dev/null -o /dev/null >/dev/null 2>&1; then
        flags+=("$candidate")
    fi
    return 0
}

build_flags() {
    local arg value index proposed opt_rank=0 debug_level=0
    local -a optimization_levels=(-O2 -O1 -Og -O0) retained=()

    if [[ $profile == school ]]; then
        [[ $family == gcc ]] || fail 'school requires GNU GCC; use --compiler=gcc or copy the preset'
        (( ! no_warnings )) || fail 'school warning policy cannot be disabled; copy the preset for customization'
        if [[ $language == c ]]; then flags=("${SCHOOL_C_FLAGS[@]}")
        else flags=("${SCHOOL_CPP_FLAGS[@]}"); fi
        if (( macro_file_io )); then flags+=("-D$DEFAULT_MACRO"); fi
        return 0
    fi

    # Only the managed region translates GNU compatibility aliases for Clang.
    # Known operands keep their literal spelling, including directory names.
    if [[ $family == clang ]]; then
        for (( index=1; index<=managed_count; ++index )); do
            arg=${compiler_args[index]}
            if compiler_operand "$arg"; then (( ++index )); continue; fi
            case "$arg" in
                --ansi) compiler_args[index]=-ansi ;;
                --no-warnings) compiler_args[index]=-w ;;
                --optimize) compiler_args[index]=-O1 ;;
                --debug) compiler_args[index]=-g2 ;;
                --optimize=*|--debug=*)
                    value=${arg#*=}
                    if [[ $value == <-> ]]; then value=${value##0#}; value=${value:-0}; fi
                    case "$arg:$value" in
                        --optimize=*:(<->|g|s|z|fast)) compiler_args[index]="-O$value" ;;
                        --debug=*:[0-3]) compiler_args[index]="-g$value" ;;
                    esac ;;
            esac
        done
    fi
    if (( ! std_seen )); then
        if [[ $DEFAULT_STANDARD == auto ]]; then detect_standard
        else
            value=$DEFAULT_STANDARD
            if [[ $value == <-> ]]; then value="$language$value"; fi
            flags+=("-std=$value")
        fi
    fi
    flags+=("${DEFAULT_FLAGS[@]}")
    if (( ! no_warnings )); then
        if [[ $family == gcc ]]; then flags+=("${WARNINGS_GCC[@]}")
        else flags+=("${WARNINGS_CLANG[@]}"); fi
    fi
    if (( macro_file_io )); then flags+=("-D$DEFAULT_MACRO"); fi
    [[ $profile != none ]] || return 0

    append_flags "${MODE_FLAGS[$profile]-}"
    if [[ $language == c++ ]]; then append_flags "${MODE_CPP_FLAGS[$profile]-}"; fi
    if [[ $language == c ]]; then append_flags "${MODE_C_FLAGS[$profile]-}"; fi
    if [[ $family == gcc ]]; then
        if [[ $language == c && -n ${MODE_C_GCC[$profile]+set} ]]; then append_flags "${MODE_C_GCC[$profile]}"
        else append_flags "${MODE_GCC[$profile]-}"; fi
        if (( ! no_warnings )); then append_flags "${MODE_WARNINGS_GCC[$profile]-}"; fi
    else
        if [[ $language == c && -n ${MODE_C_CLANG[$profile]+set} ]]; then append_flags "${MODE_C_CLANG[$profile]}"
        else append_flags "${MODE_CLANG[$profile]-}"; fi
        if (( ! no_warnings )); then append_flags "${MODE_WARNINGS_CLANG[$profile]-}"; fi
    fi
    append_native_cpu
    if [[ $language == c++ && -n ${MODE_LIBSTDCXX[$profile]-}${MODE_LIBCPP[$profile]-} ]]; then detect_library || return $?; fi
    (( debug_mode )) || return 0

    # The configured mode supplies the floor. Managed user levels may make it
    # stricter; audited tail levels may do the same but cannot weaken it.
    for arg in "${flags[@]}"; do
        case "$arg" in
            -O*|--optimize|--optimize=*)
                case "$arg" in -O*) value=${arg#-O} ;; --optimize) value=1 ;; *) value=${arg#*=} ;; esac
                value=${value##0#}; value=${value:-0}
                if [[ $arg == -O ]]; then value=1; fi
                case "$value" in 0) proposed=4 ;; g) proposed=3 ;; 1) proposed=2 ;; 2) proposed=1 ;; *) proposed=0 ;; esac
                if (( proposed > opt_rank )); then opt_rank=$proposed; fi ;;
            -g|-g<->|-ggdb|-ggdb<->|--debug|--debug=*)
                case "$arg" in --debug) value=2 ;; --debug=*) value=${arg#*=} ;; -ggdb*) value=${arg#-ggdb} ;; *) value=${arg#-g} ;; esac
                if [[ -z $value ]]; then value=2; else value=${value##0#}; value=${value:-0}; fi
                case "$value" in
                    3) debug_level=3 ;;
                    2) if (( debug_level < 2 )); then debug_level=2; fi ;;
                    1) if (( debug_level < 1 )); then debug_level=1; fi ;;
                esac ;;
        esac
    done
    audit_profile
    # Emit generated levels once, in the final effective pair. User-supplied
    # arguments keep their original spelling/order for transparent forwarding.
    for arg in "${flags[@]}"; do
        case "$arg" in
            -O|-O[0-9]#|-Og|-Os|-Oz|-Ofast) if (( opt_rank )); then continue; fi ;;
            -g|-g[0-3]|-ggdb|-ggdb[0-3]) if (( debug_level )); then continue; fi ;;
        esac
        retained+=("$arg")
    done
    flags=("${retained[@]}")
    if (( opt_rank )); then profile_levels+=("${optimization_levels[opt_rank]}"); fi
    if (( debug_level )); then profile_levels+=("-g$debug_level"); fi
}


# Source: artifacts.zsh
plan_artifact() {
    local source_file=$1 output=$2 output_given=$3 output_name= output_dir=
    if [[ $source_file == *.py ]]; then
        (( ! output_given )) || fail '-o is not applicable to Python; compile validates the original source'
        [[ -f $source_file && -r $source_file ]] || fail "source not readable: $source_file" 1
        planned_source=${source_file:A}; planned_output=$planned_source
        return
    fi
    resolve_output
    planned_source=$source_file
    planned_output="${output_dir%/}/$output_name"
}

build_artifact() {
    local source_file=$1 final=$2 profile=$3 output_abs=$2 debug_mode=0 stage= target=$2 rc=0 companion destination protected
    local -a flags=() profile_levels=() level_args=() command_args=()
    local -a sidecar_protected=("${protected_files[@]}")
    # Companion files are discovered only after compilation. Extend their
    # protection to named runtime roles without adding those roles to the
    # checker's separate source/binary list (where they would alias themselves).
    if [[ $action == test || $action == stress ]]; then
        sidecar_protected+=("${result_file:A}")
        (( console_out )) || sidecar_protected+=("$report_file")
        if [[ $action == test ]] && (( ! console_in )); then sidecar_protected+=("$input_file" "$answer_file"); fi
    elif [[ $f_mode == auto || $f_mode == in || $f_mode == out ]]; then
        [[ $f_mode == out ]] || sidecar_protected+=("$input_file")
        [[ $f_mode == in ]] || sidecar_protected+=("$result_file")
    fi
    [[ $profile == none || ${MODE_KIND[$profile]-} != debug ]] || debug_mode=1
    build_flags || return $?
    mkdir -p -- "${final:h}" || fail "cannot create binary directory: ${final:h}" 1
    # Fresh staging prevents stale binaries being run after opaque compiler
    # actions such as -fsyntax-only; an unsuccessful build preserves the old file.
    if [[ -L $final ]]; then target=${final:A}; fi
    stage=$(mktemp -d "${target:h}/.cp-run-build.XXXXXXXX") || fail 'cannot create build staging directory' 1
    CLEANUP_DIRS+=("$stage")
    command_args=("$compiler")
    # A configured GCC driver can be g++; keep the pinned C preset in C mode.
    [[ $profile != school ]] || command_args+=(-x "$language")
    command_args+=("$source_file" "${flags[@]}" "${compiler_args[@]}" "${profile_levels[@]}" -o "$stage/${target:t}")
    if (( show_command )); then printf '%q ' "${command_args[@]}" >&2; printf '\n' >&2; fi
    if (( compile_only )) || [[ $action == test || $action == stress ]]; then "${command_args[@]}" >&2 || rc=$?
    else "${command_args[@]}" || rc=$?; fi
    (( rc == 0 )) || return $rc
    [[ -f $stage/${target:t} ]] || fail 'compiler produced no fresh output artifact' 1
    if (( ! compile_only )); then [[ -x $stage/${target:t} ]] || fail 'compiler output is not executable' 126; fi
    mv -f -- "$stage/${target:t}" "$target" || fail "cannot install binary: $final" 1
    # Darwin emits .dSYM bundles beside a linked debug executable. Preserve
    # those (and ordinary compiler sidecars), otherwise external debugging
    # would lose the information requested by -g after staging is cleaned.
    for companion in "$stage"/*(DN); do
        destination="${target:h}/${companion:t}"
        for protected in "${sidecar_protected[@]}"; do
            [[ ${destination:A} != ${protected:A} && ! $destination -ef $protected ]] || fail 'compiler sidecar would overwrite a protected file' 1
            if [[ -d $companion ]]; then
                case "${protected:A}/" in "${destination:A}/"*) fail 'compiler sidecar would overwrite a protected directory' 1 ;; esac
            fi
        done
        if [[ -d $companion && -e $destination ]]; then
            [[ $companion == *.dSYM && ! -L $destination && -d $destination ]] || fail "cannot replace compiler sidecar directory: $destination" 1
            rm -rf -- "$destination" || fail "cannot replace debug symbols: $destination" 1
        fi
        mv -f -- "$companion" "$destination" || fail "cannot preserve compiler sidecar: $destination" 1
    done
    rmdir -- "$stage" 2>/dev/null || true
}


# Source: history.zsh
# History is user data, never sourced shell text. Native zsh I/O keeps the
# unlimited execution path independent of Python and external hash programs.
history_load_fields() {
    # zsh 5.9's read -d changes the controlling tty even with redirected stdin.
    # That re-echoes queued input on macOS. Read metadata without touching tty
    # modes or program stdin; the final NUL also protects trailing newlines
    # from command substitution. Return complete fields in the caller's array.
    local record
    record=$(< "$1") || return 1
    [[ $record == *$'\0' ]] || return 1
    history_fields=("${(@0)record}")
    history_fields[-1]=()
}

history_location() {
    local scope=${workspace:-$cwd} state_root=${XDG_STATE_HOME:-$HOME/.local/state}/cp-run/history
    local character digest= hi lo
    local -a history_fields=()
    local -i hash=1469598103934665603 code
    [[ -z $history_directory ]] || return 0
    # Stable FNV-style key plus a checked scope record: a collision can cause
    # an unavailable history slot, never selection of another workspace's file.
    for character in "${(@s::)scope}"; do
        printf -v code '%d' "'$character"
        (( hash = (hash ^ code) * 1099511628211 ))
    done
    printf -v digest '%08x%08x' $(( (hash >> 32) & 0xffffffff )) $(( hash & 0xffffffff ))
    zmodload -F zsh/files b:zf_mkdir b:zf_mv b:zf_rm || return 1
    local directory="$state_root/$digest"
    if ! zf_mkdir -p -m 700 -- "$directory" 2>/dev/null || [[ -L $directory || ! -O $directory ]]; then
        history_warn; return 1
    fi
    if [[ -e $directory/scope ]]; then
        history_load_fields "$directory/scope" || { history_warn; return 1; }
        [[ ${history_fields[1]-} == "$scope" ]] || { history_warn; return 1; }
    else
        # Exclusive creation resolves concurrent first use without replacing
        # an already claimed scope. NUL terminates paths containing newlines.
        (umask 077; setopt NO_CLOBBER; printf '%s\0' "$scope" > "$directory/scope") 2>/dev/null || {
            history_load_fields "$directory/scope" || { history_warn; return 1; }
            [[ ${history_fields[1]-} == "$scope" ]] || { history_warn; return 1; }
        }
    fi
    history_directory=$directory
}

history_warn() {
    if (( ! history_warning )); then
        printf '%s: warning: history is unavailable; explicit file execution continues\n' "$PROGRAM" >&2
        history_warning=1
    fi
}

history_read() {
    local -a history_fields=()
    [[ -f $history_directory/$1 && ! -L $history_directory/$1 ]] || fail "no last $1 in this workspace" 1
    history_load_fields "$history_directory/$1" || fail 'invalid history record' 1
    value=${history_fields[1]-}
    if [[ $1 == binary ]] && (( ${#history_fields} > 1 )); then
        [[ ${history_fields[2]} == CP_RUN_ARGV_V1 ]] || fail 'unsupported launch history record' 1
        (( ${#history_fields} <= 258 )) || fail 'launch history has too many arguments' 1
        recalled_launch=("${history_fields[@]:2}")
    fi
    [[ -n $value && -f $value && -r $value ]] || fail "last $1 is missing or unreadable: $value" 1
    [[ $1 != binary || $value == *.py || -x $value ]] || fail "last binary is no longer executable: $value" 126
    if (( ${#recalled_launch} )); then
        [[ ${recalled_launch[-1]} == "$value" && -x ${recalled_launch[1]} ]] || fail 'recorded interpreter/source is no longer available' 1
    fi
}

history_write() {
    history_location || return 0
    local temporary="$history_directory/.$1.$$.${RANDOM}${RANDOM}" target="$history_directory/$1"
    (umask 077; setopt NO_CLOBBER; printf '%s\0' "${@:2}" > "$temporary" && zf_mv -f -- "$temporary" "$target") 2>/dev/null || {
        zf_rm -f -- "$temporary" 2>/dev/null; history_warn
    }
    return 0
}

# Source: dispatch.zsh
# A counted argv transport avoids JSON escaping in shell and never consumes
# program stdin. Python is loaded once for a complete measured/test/stress job.
python_action() {
    embedded_python "$1" "${#config}" "${(@kv)config}" "${#runtime_args}" "${runtime_args[@]}" "${#protected_files}" "${protected_files[@]}"
}

# EXIT runs after main's locals expire. Its small registry deliberately has
# script scope so cleanup never expands an unset local after a failed action.
typeset -ga CLEANUP_DIRS=()
cleanup() {
    local directory
    for directory in "${CLEANUP_DIRS[@]}"; do [[ ! -d $directory ]] || rm -rf -- "$directory"; done
}

main() {
    local interpreter_info=
    # Discovery fallbacks remain editable data, scoped to this invocation.
    local DEFAULT_SOURCE=$DEFAULT_SOURCE C_SOURCE=$C_SOURCE PYTHON_SOURCE=$PYTHON_SOURCE
    local language=c++ primary_language=c++ interpreter= interpreter_choice=$DEFAULT_INTERPRETER language_choice=$DEFAULT_LANGUAGE
    local action=ordinary source_file= compiler_choice=$DEFAULT_COMPILER family= compiler= compiler_banner= profile=none
    local main_wsp= main_wsp_given=0
    local workspace_dir=$DEFAULT_WORKSPACE workspace_name= destination=$DEFAULT_DESTINATION workspace= workspace_prefix=
    local output= output_dir= output_name= output_abs= planned_source= planned_output= resolved_binary= auto_standard=
    local input_file=$DEFAULT_INPUT result_file=$DEFAULT_OUTPUT answer_file=$DEFAULT_ANSWER report_file=$DEFAULT_REPORT
    local brute_file=$DEFAULT_BRUTE generator_file=$DEFAULT_GENERATOR find_name= f_mode=none separator=$DEFAULT_SEPARATOR
    local timeout_ms=inf memory_mib=inf num_test= seed= python= cwd=$PWD
    local warmup=$DEFAULT_WARMUP average=$DEFAULT_AVERAGE time_unit=$DEFAULT_TIME_UNIT memory_unit=$DEFAULT_MEMORY_UNIT
    local transfer_action= transfer_path= history_directory= history_warning=0
    local value option_name arg index previous role base_profile=none temporary= current_profile previous_profile
    local -i argument_count=$# binary_mode=0 auto=0 dir_given=0 name_given=0 destination_given=0 output_given=0 save_relpath=0 std_seen=0
    local -i no_warnings=0 macro_file_io=0 show_command=0 measure_time=0 measure_memory=0
    local -i console_in=0 console_out=0 sep_given=0 help_requested=0 version_requested=0 managed_count=0
    local test_folder=$DEFAULT_TEST_FOLDER
    local bundle_format=legacy bundle_stream=both report_tests=$DEFAULT_REPORT_TESTS
    local minimize= validator=
    local format_cache=1 strict_formatter= review=0 annotate=0 review_report=
    local format_mode=$FORMAT_MODE prettier= companion_port=$COMPANION_PORT companion_wait=$COMPANION_WAIT
    local -i doctor_requested=0 interpreter_given=0 compiler_given=0
    local -i data_controls=0 layout_controls=0 companion_controls=0 report_controls=0 bundle_given=0
    local -i overwrite=0 stop_on_failure=0
    local -i positional_count=0 mult=0 relpath_given=0
    local -i timeout_given=0 memory_given=0 measurement_controls=0 debug_run=0 compile_only=0 result_given=0
    local -a interpreter_args=() recalled_launch=() launch_args=() primary_launch=() original_compiler_args=() original_standards=()
    local -a compiler_args=() runtime_args=() cases=() sources=() artifacts=() protected_files=() build_indices=()
    local -A config=() compiler_paths=() compiler_banners=() standard_vocab=()
    local -a managed_standards=() supported_standards=()

    # One cleanup owner covers build staging and a console-input snapshot.
    # A normal exec replaces this process only after all temporary work is done.
    trap cleanup EXIT
    parse_cli "$@"
    # Build-only debug retains its own profile/routing defaults. Only an
    # explicit run modifier permits runtime I/O, observation and execution.
    if [[ $action == compile || $action == debug && $debug_run == 0 ]]; then compile_only=1; fi
    if (( help_requested )); then show_help; return; fi
    if (( main_wsp_given )); then
        (( ! dir_given && ! name_given )) || fail '--main-wsp conflicts with --wsp-dir and --wsp-name'
        resolve_workspace_root
    fi
    if [[ $action == configure ]]; then
        (( argument_count == 1 )) || fail 'use cp-run configure on its own'
        embedded_python settings "$SCRIPT_PATH"; return $?
    fi
    if (( doctor_requested )); then
        config=(interpreter "$interpreter_choice" native_formatter "$NATIVE_FORMATTER" python_formatter "$PYTHON_FORMATTER")
        python_action doctor; return $?
    fi
    if (( ! format_cache )); then
        [[ -n $prettier || -n $strict_formatter ]] || fail '--no-cache requires format or --strict-format'
    fi
    if (( review || annotate )); then
        [[ -n $prettier ]] || fail '--review and --annotate require format'
    fi
    if (( annotate )); then (( review )) || fail '--annotate requires --review'; fi
    if [[ -n $review_report && -z $prettier && -z $strict_formatter ]]; then
        fail '--report requires format or --strict-format'
    fi
    [[ -z $prettier || -z $strict_formatter ]] || fail '--strict-format is a compilation option'
    # Formatting is a terminal action, before artifact planning or any compiler
    # lookup. A successful formatter can never fall through into preparation/run.
    if [[ -n $prettier ]]; then
        (( ! binary_mode && ! ${#compiler_args} && ! ${#runtime_args} && ! output_given && ! result_given &&
           ! measure_time && ! measure_memory && ! measurement_controls && ! timeout_given && ! memory_given )) &&
            [[ $f_mode == none ]] || fail 'formatting does not compile or run; remove build/runtime options'
        [[ $action != companion && $action != pack && $action != unpack ]] || fail 'formatting requires a source operation'
        [[ $profile == none || -n ${MODE_KIND[$profile]-} ]] || fail "profile not found: $profile"
        [[ $action != debug || ${MODE_KIND[$profile]-} == debug ]] || fail "profile '$profile' is a flags set; select it with --profile=$profile"
        if [[ $source_file == - ]]; then
            resolve_workspace_root
            history_location || fail 'source history is not accessible' 1
            history_read source; source_file=$value
        fi
        if [[ -n $source_file ]]; then workspace_file_path "$source_file"; source_file=$value
        else select_source; fi
        protected_files=("${source_file:A}")
        if [[ $action == stress ]]; then
            source_language "$source_file"; primary_language=$language
            if (( positional_count < 2 )); then discover_role "$brute_file" brute; brute_file=$value; fi
            if (( positional_count < 3 )); then discover_role "$generator_file" gen; generator_file=$value; fi
            for role in "$brute_file" "$generator_file"; do
                workspace_file_path "$role"; protected_files+=("${value:A}")
            done
        fi
        if [[ -n $review_report ]]; then workspace_file_path "$review_report"; review_report=$value; fi
        config=(format_mode "$format_mode" prettier "$prettier" native_formatter "$NATIVE_FORMATTER" python_formatter "$PYTHON_FORMATTER"
                review "$review" annotate "$annotate" review_report "$review_report" overwrite "$overwrite" script "$SCRIPT_PATH" format_cache "$format_cache")
        python_action format; return $?
    fi
    if [[ -n $transfer_action ]]; then
        [[ -z $source_file && ${#compiler_args} == 0 && ${#runtime_args} == 0 ]] &&
            (( argument_count <= 2 && ! version_requested )) && [[ $action != configure ]] || fail 'use settings transfer on its own'
        embedded_python "$transfer_action" "$SCRIPT_PATH" "$transfer_path"; return $?
    fi
    case "${compiler_choice:l}" in gcc|g++) family=gcc ;; clang|clang++) family=clang ;; *) fail 'compiler must be GCC, gcc, g++, clang or clang++' ;; esac
    if (( version_requested )) && { (( interpreter_given )) || [[ $source_file == *.py || -z $source_file && $language_choice == python && $compiler_given == 0 ]]; }; then
        printf '%s %s\n' "$PROGRAM" "$VERSION"; resolve_interpreter; "$interpreter" --version; return $?
    fi
    if (( ! compiler_given )); then
        value=$language_choice
        if [[ -n $source_file ]]; then source_language "$source_file"; value=$language; fi
        [[ $value == c ]] || value=c++
        language=$value
        compiler_choice=${LANGUAGE_COMPILERS[$value]-$DEFAULT_COMPILER}
        case "${compiler_choice:l}" in gcc|g++) family=gcc ;; *) family=clang ;; esac
    fi
    if (( version_requested )); then printf '%s %s\n' "$PROGRAM" "$VERSION"; resolve_compiler; "$compiler" --version; return $?; fi

    (( ! companion_controls )) || [[ $action == companion ]] || fail '--port/--wait require companion'
    (( ! data_controls )) || [[ $action == pack || $action == unpack || $action == companion || -n $strict_formatter && -n $review_report ]] || fail 'import controls require pack/unpack/companion'
    (( ! layout_controls )) || (( mult )) || [[ $action == pack || $action == unpack || $action == companion ]] || fail 'layout options require mult/pack/unpack/companion'
    (( ! report_controls )) || [[ $action == test || $action == stress ]] || fail '--report-tests requires test/stress'
    (( ! stop_on_failure )) || [[ $action == stress ]] || fail '--stop-on-failure requires stress'
    if (( bundle_given )); then [[ $action == test && $auto == 1 ]] || fail '--bundle-format requires test=auto'; fi
    if [[ $action == companion || $action == pack || $action == unpack ]]; then
        (( ! ${#compiler_args} && ! ${#runtime_args} && ! output_given && ! measure_time && ! measure_memory )) && [[ $f_mode == none && -z $prettier ]] || fail 'data operations cannot compile or run programs'
    fi
    # Cheap option conflicts precede file opens and all compiler discovery.
    [[ $profile == none || -n ${MODE_KIND[$profile]-} ]] || fail "profile not found: $profile; use cp-run configure"
    if [[ $profile != none && ${MODE_KIND[$profile]} == debug ]] && (( no_warnings )); then fail 'debug profile conflicts with --no-w'; fi
    if [[ $action == debug && ${MODE_KIND[$profile]} != debug ]]; then
        fail "profile '$profile' is a flags set; select it with --profile=$profile"
    fi
    if [[ $action == test || $action == stress ]]; then [[ $f_mode == none ]] || fail '-f is unavailable in test/stress'; fi
    (( ! measurement_controls || measure_time || measure_memory )) || fail '--warm-up/--average require -t or -m'
    # In ordinary/run execution, override one side of auto redirection. Reuse
    # the existing in/out paths so direct and measured launches stay identical;
    # test/stress retain their separate protocol-specific console semantics.
    if [[ $action != test && $action != stress ]] && (( console_in || console_out )); then
        [[ $f_mode == auto ]] || fail '--cin/--cout require -f with saved auto mode outside test/stress'
        (( ! (console_in && console_out) )) || fail '-f in auto mode cannot combine --cin and --cout'
        if (( console_in )); then f_mode=out; else f_mode=in; fi
        console_in=0; console_out=0
    fi
    if [[ $action != test ]]; then (( ! console_in )) || fail '--cin is only available in test'; fi
    if [[ $action != test && $action != stress ]]; then
        (( ! console_out )) && [[ -z $num_test ]] || fail 'test/stress options require test or stress'
    fi
    [[ -z $seed || $action == stress ]] || fail '--seed requires stress'
    [[ -z $minimize && -z $validator || $action == stress ]] || fail 'counterexample reduction requires stress'
    [[ -z $validator || -n $minimize ]] || fail '--validator requires --minimize'
    if [[ $minimize == lines || $minimize == cases ]]; then [[ -n $validator ]] || fail 'this reduction strategy requires --validator'; fi
    resolve_action_defaults
    # Select routing defaults after parsing so an explicit destination wins
    # in either option order. Exact -o paths still bypass routing entirely.
    if [[ $action == stress ]]; then
        seed=${seed:-$DEFAULT_SEED}
        # Compare equal-width decimal strings: zsh arithmetic is signed, while
        # generator seeds cover all 64 unsigned bits. No Python/probe is needed.
        [[ $seed == [0-9]## && ${#seed} -le 20 ]] &&
            [[ ${#seed} -lt 20 || $seed < 18446744073709551616 ]] || fail '--seed must be an unsigned 64-bit integer'
    fi
    if (( sep_given )); then [[ $action == test && $auto == 1 || $action == pack || $action == unpack ]] || fail '--sep requires test=auto or pack/unpack'; fi
    if [[ $action == test ]] && (( ! auto && ! mult && sep_given )); then fail '--sep requires test=auto'; fi
    if (( binary_mode )); then
        [[ $profile == none && $f_mode != macro ]] && (( ! ${#compiler_args} && ! output_given )) || fail 'binary execution cannot use compilation options'
    elif [[ -n $find_name ]]; then fail '--find requires run, test run or stress run'; fi
    if (( compile_only )); then
        (( ! measure_time && ! measure_memory && ! ${#runtime_args} )) && [[ $f_mode != auto && $f_mode != in && $f_mode != out ]] || fail 'runtime options require an execution command'
    fi
    if (( result_given )); then
        [[ $action == test || $action == stress || $f_mode == auto || $f_mode == out ]] || fail '--out requires test/stress or -f with auto output redirection'
    fi
    case "$f_mode" in none|auto|in|out) ;; macro) macro_file_io=1 ;; *) fail 'invalid saved -f mode; use cp-run configure' ;; esac
    [[ $DEFAULT_MACRO == [A-Za-z_][A-Za-z0-9_]# ]] || fail 'FILEO macro setting must be a C identifier'
    for option_name value in --TLE "$timeout_ms" --MLE "$memory_mib"; do
        [[ $value == inf ]] && continue
        [[ $value == <-> && ${#value} -le 12 ]] && (( 10#$value > 0 )) || fail "$option_name requires a positive integer (up to 12 digits) or inf"
    done
    cwd=$(pwd -P) || fail 'cannot resolve the current directory' 1
    if (( ${#EXTRA_WORKSPACES} && ! binary_mode )) && [[ -z $source_file && $action != (pack|unpack|companion) ]]; then
        select_source
    fi
    # Expand only file roles used by this operation; unused preferences must
    # not turn a direct run/-o invocation into a workspace lookup.
    if [[ -n $source_file ]]; then workspace_file_path "$source_file"; source_file=$value; fi
    if (( output_given )); then workspace_file_path "$output"; output=$value; fi
    if [[ $action == test ]] && (( ! console_in && ! mult )); then
        workspace_file_path "$input_file"; input_file=$value
        workspace_file_path "$answer_file"; answer_file=$value
    fi
    if [[ $action == test || $action == stress ]] && (( ! console_out )); then
        workspace_file_path "$report_file"; report_file=$value
    fi
    if [[ $f_mode == auto || $f_mode == in ]]; then workspace_file_path "$input_file"; input_file=$value; fi
    if [[ $action == test || $action == stress || $f_mode == auto || $f_mode == out ]]; then
        workspace_file_path "$result_file"; result_file=$value
    fi
    if [[ -n $validator ]]; then
        workspace_file_path "$validator"; validator=${value:A}
        [[ -f $validator && ( -x $validator || $validator == *.py ) ]] || fail 'validator must be executable or a Python script'
    fi
    if [[ $action == stress ]]; then
        workspace_file_path "$brute_file"; brute_file=$value
        workspace_file_path "$generator_file"; generator_file=$value
    fi
    if [[ $action == pack || $action == unpack ]]; then
        if [[ $bundle_stream != ans ]]; then workspace_file_path "$input_file"; input_file=$value; fi
        if [[ $bundle_stream != in ]]; then workspace_file_path "$answer_file"; answer_file=$value; fi
    fi
    if [[ $source_file == - ]]; then
        resolve_workspace
        history_location || fail 'launch history is not accessible' 1
        if (( binary_mode )); then history_read binary; else history_read source; fi
        source_file=$value
    fi

    # Scan native standards without interpreting opaque tail values. Known
    # operands can themselves look like flags and must never suppress defaults.
    for (( index=1; index<=${#compiler_args}; ++index )); do
        arg=${compiler_args[index]}
        case "$arg" in -std=*|--std=*|--std|-ansi|--ansi) std_seen=1 ;; esac
        if compiler_operand "$arg"; then (( ++index )); fi
    done
    # Resolve data independently from binary destinations and source discovery.
    # Only workspace-prefixed folders trigger a workspace lookup.
    if (( mult )) || [[ $action == companion || $action == pack || $action == unpack ]]; then
        if [[ $test_folder == '{wsp-dir}' ]]; then resolve_workspace_root; test_folder=$workspace
        else workspace_file_path "$test_folder"; test_folder=$value; fi
    fi
    if [[ $action == companion ]]; then
        config=(test_folder "$test_folder" overwrite "$overwrite" port "$companion_port"
                wait "$companion_wait" max_spool "$MAX_SPOOL_BYTES")
        [[ -z $source_file ]] || protected_files=("${source_file:A}")
        python_action companion; return $?
    fi
    if [[ $action == pack || $action == unpack ]]; then
        config=(operation "$action" test_folder "$test_folder" default_input "$input_file" default_answer "$answer_file"
                bundle_stream "$bundle_stream" sep "$separator" overwrite "$overwrite" max_spool "$MAX_SPOOL_BYTES")
        python_action "$action"; return $?
    fi
    if (( binary_mode )); then
        resolve_binary "$source_file"; artifacts+=("$resolved_binary"); protected_files+=("$resolved_binary")
        if [[ $action == stress ]]; then
            (( positional_count == 3 )) || fail 'stress run requires explicit BRUTE and GEN binary paths'
            resolve_binary "$brute_file"; artifacts+=("$resolved_binary"); protected_files+=("$resolved_binary")
            resolve_binary "$generator_file"; artifacts+=("$resolved_binary"); protected_files+=("$resolved_binary")
        fi
    else
        [[ -n $source_file ]] || select_source
        source_language "$source_file"; primary_language=$language
        plan_artifact "$source_file" "$output" "$output_given"
        sources+=("$planned_source"); artifacts+=("$planned_output")
        if [[ $action == stress ]]; then
            if (( positional_count < 2 )); then discover_role "$brute_file" brute; brute_file=$value; fi
            if (( positional_count < 3 )); then discover_role "$generator_file" gen; generator_file=$value; fi
            for role in "$brute_file" "$generator_file"; do
                plan_artifact "$role" '' 0
                sources+=("$planned_source"); artifacts+=("$planned_output")
            done
        fi
        # Reuse an identical source/configuration; distinct configurations must
        # not silently overwrite one another through equal flat basenames.
        for (( index=1; index<=${#artifacts}; ++index )); do
            build_indices[index]=$index
            for value in "${sources[@]}"; do
                [[ ${sources[index]} != *.py || ${artifacts[index]:A} != ${value:A} ]] || continue
                [[ ${artifacts[index]:A} != ${value:A} && ! ${artifacts[index]} -ef $value ]] || fail 'binary output collides with another source or artifact'
            done
            for (( previous=1; previous<index; ++previous )); do
                if [[ ${artifacts[index]:A} == ${artifacts[previous]:A} || ${artifacts[index]} -ef ${artifacts[previous]} ]]; then
                    current_profile=none; previous_profile=none
                    (( index != 1 )) || current_profile=$profile
                    (( previous != 1 )) || previous_profile=$profile
                    if [[ ${sources[index]} -ef ${sources[previous]} && $current_profile == "$previous_profile" ]]; then build_indices[index]=$previous
                    else fail 'binary outputs collide; use distinct source basenames for different builds'; fi
                fi
            done
        done
        protected_files=("${sources[@]}" "${artifacts[@]}")
    fi
    if [[ -n $strict_formatter ]]; then
        (( ! binary_mode )) || fail '--strict-format needs source files'
        local -a all_protected=("${protected_files[@]}")
        protected_files=("${sources[@]}" "${artifacts[@]}" "$input_file" "$answer_file" "$result_file")
        if [[ -n $review_report ]]; then workspace_file_path "$review_report"; review_report=$value; fi
        config=(format_mode "$strict_formatter" prettier check native_formatter "$NATIVE_FORMATTER" python_formatter "$PYTHON_FORMATTER"
                review_report "$review_report" overwrite "$overwrite" script "$SCRIPT_PATH" format_cache "$format_cache" format_source_count "${#sources}")
        for (( value=1; value<=${#sources}; ++value )); do config[format_source_$value]=${sources[value]}; done
        python_action strict-format || return $?
        protected_files=("${all_protected[@]}")
    fi
    output_abs=${artifacts[1]}
    config=(operation "$action" auto "$auto" mult "$mult" workspace "${workspace:-$cwd}" destination "$destination"
            test_folder "$test_folder" bundle_format "$bundle_format"
            minimize "$minimize" validator "$validator" validator_interpreter "$interpreter_choice" minimize_attempts "$MINIMIZE_ATTEMPTS" minimize_seconds "$MINIMIZE_SECONDS"
            report_tests "$report_tests" stop_on_failure "$stop_on_failure" max_failures "$MAX_FAILURES" input "$input_file" answer "$answer_file" report "$report_file"
            actual "$result_file" sep "$separator" cases "${(j:,:)cases}" num_test "$num_test"
            line_limit "$DEFAULT_LINE_LIMIT" cin "$console_in" cout "$console_out" executable "$output_abs"
            timeout_ms "$timeout_ms" memory_mib "$memory_mib" show_time "$measure_time" show_memory "$measure_memory"
            show_command "$show_command" seed "$seed" iterations "$DEFAULT_ITERATIONS" script "$SCRIPT_PATH"
            warmup "$warmup" average "$average" time_unit "$time_unit" memory_unit "$memory_unit"
            time_factor "$TIME_KILL_FACTOR" memory_factor "$MEMORY_KILL_FACTOR"
            max_line "$MAX_LINE_BYTES" max_check "$MAX_CHECK_BYTES" max_report "$MAX_REPORT_BYTES"
            report_lines "$MAX_REPORT_LINES" max_spool "$MAX_SPOOL_BYTES")
    if [[ $action == stress ]]; then config[brute]=${artifacts[2]}; config[generator]=${artifacts[3]}; fi
    if [[ $action == test || $action == stress ]]; then
        if (( console_in )); then
            temporary=$(mktemp -d "${TMPDIR:-/tmp}/cp-run-input.XXXXXXXX") || fail 'cannot prepare console input' 1
            CLEANUP_DIRS+=("$temporary")
            config[console_cache]="$temporary/console.json"
        fi
        python_action preflight || return $?
    elif [[ $f_mode == auto || $f_mode == in || $f_mode == out ]]; then
        if [[ $f_mode != in ]]; then
            local -a redirect_protected=("${protected_files[@]}")
            [[ $f_mode != auto ]] || redirect_protected+=("$input_file")
            for value in "${redirect_protected[@]}"; do
                [[ ${result_file:A} != ${value:A} && ! $result_file -ef $value ]] || fail 'redirected output would overwrite an input, source or binary' 1
            done
        fi
        if [[ $f_mode != out ]]; then
            for value in "${artifacts[@]}"; do [[ ${value:A} != ${input_file:A} && ! $value -ef $input_file ]] || fail 'binary output would overwrite runtime input' 1; done
        fi
    fi
    if (( ! binary_mode )); then
        original_compiler_args=("${compiler_args[@]}")
        original_standards=("${managed_standards[@]}")
        base_profile=$profile
        local native_standard=$DEFAULT_STANDARD primary_managed_count=$managed_count
        for (( index=1; index<=${#sources}; ++index )); do
            case $index in 1) role=main ;; 2) role=brute ;; 3) role=generator ;; esac
            if (( build_indices[index] != index )); then
                local reused_role
                case ${build_indices[index]} in 1) reused_role=main ;; 2) reused_role=brute ;; esac
                launch_args=()
                for (( value=1; value<=config[launch_${reused_role}_count]; ++value )); do launch_args+=("${config[launch_${reused_role}_${value}]}"); done
                record_launch "$role"
                config[tool_$role]=${config[tool_$reused_role]-}
                continue
            fi
            profile=$base_profile; (( index == 1 )) || profile=none
            source_language "${sources[index]}"
            managed_count=$primary_managed_count
            compiler_args=("${original_compiler_args[@]}"); managed_standards=("${original_standards[@]}")
            auto_standard=; supported_standards=(); compiler_banner=
            if [[ $language == python ]]; then
                if (( index == 1 )); then
                    (( ! output_given && ! macro_file_io && ! std_seen )) || fail 'Python does not use -o, -std or a file-I/O macro'
                fi
                python_launch "${sources[index]}" "$profile" || return $?
                if (( compile_only )) || [[ $action == test || $action == stress ]]; then
                    compiler_banner=$("$interpreter" -c 'import pathlib,sys; p=sys.argv[1]; compile(pathlib.Path(p).read_bytes(), p, "exec"); print(sys.implementation.name, sys.version)' "${sources[index]}") || {
                        local build_status=$?
                        if [[ $action == test || $action == stress ]]; then config[build_status]=$build_status; config[failed_role]=$role; python_action ce; fi
                        return $build_status
                    }
                fi
            else
                if [[ $primary_language == python ]]; then compiler_args=(); managed_standards=(); managed_count=0; std_seen=0; fi
                # Translate only managed numeric shorthand after language discovery.
                for (( value=1; value<=managed_count; ++value )); do
                    arg=${compiler_args[value]}
                    if compiler_operand "$arg"; then (( ++value )); continue; fi
                    if [[ $arg == -std=<-> ]]; then compiler_args[value]="-std=$language${arg#-std=}"; fi
                done
                for (( value=1; value<=${#managed_standards}; ++value )); do
                    [[ ${managed_standards[value]} != <-> ]] || managed_standards[value]="$language${managed_standards[value]}"
                done
                local DEFAULT_STANDARD=$native_standard
                [[ $language != c ]] || DEFAULT_STANDARD=$C_STANDARD
                # Each native role chooses its own family; an explicit CLI
                # compiler applies to all roles and wins over saved preferences.
                if (( ! compiler_given )); then
                    if [[ $profile == school ]]; then compiler_choice=GCC
                    else compiler_choice=${LANGUAGE_COMPILERS[$language]-$DEFAULT_COMPILER}; fi
                fi
                case "${compiler_choice:l}" in gcc|g++) family=gcc ;; *) family=clang ;; esac
                if [[ -n ${compiler_paths[$language]-} ]]; then
                    compiler=${compiler_paths[$language]}; compiler_banner=${compiler_banners[$language]}
                    supported_standards=("${(@s: :)standard_vocab[$language]}")
                    [[ -n ${supported_standards[1]-} ]] || supported_standards=()
                else
                    resolve_compiler
                    compiler_paths[$language]=$compiler; compiler_banners[$language]=$compiler_banner
                fi
                if (( ! std_seen )) && [[ $DEFAULT_STANDARD != auto ]]; then
                    value=$DEFAULT_STANDARD; [[ $value != <-> ]] || value="$language$value"
                    managed_standards+=("$value")
                fi
                if (( ${#managed_standards} )); then validate_standards; fi
                local build_status=0
                build_artifact "${sources[index]}" "${artifacts[index]}" "$profile" || build_status=$?
                if (( build_status )); then
                    if [[ $action == test || $action == stress ]]; then
                        config[build_status]=$build_status; config[failed_role]=$role
                        python_action ce
                    fi
                    return $build_status
                fi
                standard_vocab[$language]="${(j: :)supported_standards}"
                launch_args=("${artifacts[index]}")
            fi
            case $index in 1) role=main; primary_launch=("${launch_args[@]}") ;; 2) role=brute ;; 3) role=generator ;; esac
            record_launch "$role"
            config[tool_$role]="$compiler_banner"
        done
        profile=$base_profile
        history_write source "${sources[1]}"
    else
        for (( index=1; index<=${#artifacts}; ++index )); do
            source_language "${artifacts[index]}"
            if [[ $language == python ]]; then
                if (( index == 1 && ${#recalled_launch} && ! interpreter_given )); then
                    # Keep the recorded interpreter/profile, but honour newly
                    # explicit interpreter options before the original source.
                    audit_python_options 0 default "${interpreter_args[@]}"
                    launch_args=("${(@)recalled_launch[1,-2]}" "${interpreter_args[@]}" "${artifacts[index]}")
                else python_launch "${artifacts[index]}" none || return $?; fi
            else launch_args=("${artifacts[index]}"); fi
            case $index in 1) role=main; primary_launch=("${launch_args[@]}") ;; 2) role=brute ;; 3) role=generator ;; esac
            record_launch "$role"
            if [[ $language == python && ( $action == test || $action == stress ) ]]; then
                if [[ -z $interpreter_info ]]; then interpreter_info=$("${launch_args[1]}" --version) || return $?; fi
                config[tool_$role]=$interpreter_info
            fi
        done
    fi
    if (( compile_only )); then printf '%s\n' "$output_abs"; return; fi
    if history_location; then config[history_binary]="$history_directory/binary"; fi
    if [[ $action == test || $action == stress ]]; then python_action "$action"; return $?; fi

    if (( show_command )) && [[ $f_mode == auto || $f_mode == in || $f_mode == out ]]; then
        printf '%q ' "${primary_launch[@]}" "${runtime_args[@]}" >&2
        if [[ $f_mode != out ]]; then printf '< %q ' "$input_file" >&2; fi
        if [[ $f_mode != in ]]; then printf '> %q' "$result_file" >&2; fi
        printf '\n' >&2
        config[show_command]=0; show_command=0
    fi
    # Redirect before launching the observer so it can replay the same input.
    # Direct and measured execution inherit identical program descriptors.
    if [[ $f_mode == auto || $f_mode == in ]]; then
        exec < "$input_file" || return $?
    fi
    if [[ $f_mode == auto || $f_mode == out ]]; then exec > "$result_file" || return $?; fi
    if (( measure_time || measure_memory )) || [[ $timeout_ms != inf || $memory_mib != inf ]]; then
        python_action supervise
        return $?
    fi
    if (( show_command )); then printf '%q ' "${primary_launch[@]}" "${runtime_args[@]}" >&2; printf '\n' >&2; fi
    if [[ $output_abs == *.py ]]; then history_write binary "$output_abs" CP_RUN_ARGV_V1 "${primary_launch[@]}"
    else history_write binary "$output_abs"; fi
    cleanup
    exec -- "${primary_launch[@]}" "${runtime_args[@]}"
}

# Source: launcher.zsh
# Payload arrives on fd 3; fd 0 remains the program/menu input. The bootstrap
# is constant-sized even when the embedded services grow beyond Linux argv limits.
embedded_python() {
    if [[ -z $python ]]; then python=$(whence -p -- python3 2>/dev/null) || fail 'this feature requires Python 3.9+' 127; fi
    # Services use only stdlib; -S avoids unnecessary site-package startup.
    # This affects the observer/editor, never the user's executable environment.
    "$python" -S -c 'import os; f=os.fdopen(3, "r", encoding="utf-8"); code=f.read(); f.close(); exec(compile(code, "<cp-run>", "exec"))' "$@" 3<<'CP_RUN_PYTHON'
# Source: memory.py
"""Platform resident-memory backends used only when observation requires RSS."""

import ctypes
import errno
import os
import sys

class MacMemory:
    """Read process-group resident bytes directly through macOS libproc."""

    class TaskInfo(ctypes.Structure):
        _fields_ = [(name, ctypes.c_uint64) for name in (
            "virtual_size", "resident_size", "total_user", "total_system",
            "threads_user", "threads_system",
        )] + [("remaining", ctypes.c_int32 * 12)]

    def __init__(self):
        self.lib = ctypes.CDLL("/usr/lib/libproc.dylib", use_errno=True)
        self.lib.proc_listpids.argtypes = [ctypes.c_uint32, ctypes.c_uint32,
                                          ctypes.c_void_p, ctypes.c_int]
        self.lib.proc_listpids.restype = ctypes.c_int
        self.lib.proc_pidinfo.argtypes = [ctypes.c_int, ctypes.c_int,
                                         ctypes.c_uint64, ctypes.c_void_p,
                                         ctypes.c_int]
        self.lib.proc_pidinfo.restype = ctypes.c_int

    def sample(self, group):
        # Query only the child's group. Unrelated processes do not add memory
        # or permission errors, and no external ps command is needed per tick.
        ctypes.set_errno(0)
        size = self.lib.proc_listpids(2, group, None, 0)  # PROC_PGRP_ONLY = 2.
        if size < 0 or (size == 0 and ctypes.get_errno() not in (0, errno.ESRCH)):
            raise OSError(ctypes.get_errno(), "proc_listpids")
        slots = max(16, size // ctypes.sizeof(ctypes.c_int) + 16)
        while True:
            pids = (ctypes.c_int * slots)()
            ctypes.set_errno(0)
            count = self.lib.proc_listpids(2, group, pids, ctypes.sizeof(pids))
            if count < 0 or (count == 0 and ctypes.get_errno() not in (0, errno.ESRCH)):
                raise OSError(ctypes.get_errno(), "proc_listpids")
            if count < ctypes.sizeof(pids):
                break
            slots *= 2  # Membership may grow between sizing and retrieval.

        total = 0
        for pid in pids[:count // ctypes.sizeof(ctypes.c_int)]:
            if pid <= 0:
                continue
            info = self.TaskInfo()
            ctypes.set_errno(0)
            size = self.lib.proc_pidinfo(pid, 4, 0, ctypes.byref(info),
                                         ctypes.sizeof(info))  # PROC_PIDTASKINFO.
            if size == ctypes.sizeof(info):
                total += info.resident_size
            elif size <= 0 and ctypes.get_errno() not in (0, errno.ESRCH):
                raise OSError(ctypes.get_errno(), "proc_pidinfo")
            elif size > 0:
                raise OSError(errno.EIO, "incomplete proc_taskinfo")
        return total


class LinuxMemory:
    """Sum RSS pages in the child's process group on secondary Linux hosts."""

    def __init__(self):
        self.page_size = os.sysconf("SC_PAGE_SIZE")

    def sample(self, group):
        total = 0
        for entry in os.scandir("/proc"):
            if not entry.name.isdigit():
                continue
            try:
                if os.getpgid(int(entry.name)) != group:
                    continue
                # A command can contain spaces and ')'; stat fields begin
                # after the final ')'. RSS is field 24, pgrp is field 5.
                with open(entry.path + "/stat", encoding="ascii", errors="replace") as stream:
                    fields = stream.read().rsplit(")", 1)[1].split()
                if int(fields[2]) == group:
                    total += int(fields[21]) * self.page_size
            except (FileNotFoundError, ProcessLookupError):
                pass  # A group member may exit between membership and RSS.
            except PermissionError:
                # Never silently advertise a limit that could not be observed.
                try:
                    belongs = os.getpgid(int(entry.name)) == group
                except (ProcessLookupError, PermissionError):
                    belongs = False
                if belongs:
                    raise
        return total




# Source: runtime.py
"""Accurate process execution, measurements and soft local-runner limits.

This module is embedded into cp-run.zsh at release time. It deliberately uses
only Python's standard library and never captures or replays program stderr.
Elapsed time is wall time around the child launch/wait, not CPU time or the
time spent importing Python, preparing cases, compiling, or writing reports.
"""

from dataclasses import dataclass
import os
import select
import shlex
import signal
import subprocess
import sys
import time



MIB = 1024 * 1024
POLL_NS = 5_000_000  # RSS is sampled every 5 ms; child exit is signal-driven.


@dataclass(frozen=True)
class Result:
    """One process outcome; verdict is separate from its numeric exit code."""

    status: int
    elapsed_ns: int
    peak_bytes: int
    verdict: str


def _budget(value, scale):
    """Return an integer budget, or None for infinity; avoid float clocks."""
    text = str(value)
    if text == "inf":
        return None
    if (not text.isascii() or not text.isdecimal() or len(text) > 12
            or int(text) <= 0):
        raise ValueError("budgets must be positive integers of up to 12 digits or inf")
    return int(text) * scale


def _factor(value):
    """Exact bounded decimal ratio; grace factors must be finite and >= 1."""
    import re
    text = str(value)
    if len(text) > 12 or not re.fullmatch(r'[0-9]+(?:\.[0-9]+)?', text):
        raise ValueError('kill factor must be a finite decimal >= 1 (up to 12 characters)')
    whole, _, fraction = text.partition('.')
    denominator = 10 ** len(fraction)
    numerator = int(whole) * denominator + int(fraction or '0')
    if numerator < denominator: raise ValueError('kill factor must be >= 1')
    return numerator, denominator


def format_usage(value, unit, memory=False):
    """Convert integer base units only for display, using decimal half-up rounding."""
    scales = {'s': 1_000_000_000, 'ms': 1_000_000} if not memory else {
        'B': 1, 'KB': 1000, 'KiB': 1024, 'MB': 1_000_000, 'MiB': MIB}
    if unit not in scales: raise ValueError('unsupported measurement unit: ' + str(unit))
    def shown(target):
        scale = scales[target]
        if memory and target in ('B', 'KiB'):
            return '{} {}'.format((value + scale - 1) // scale, target)
        thousandths = (value * 1000 * 2 + scale) // (2 * scale)
        return '{}.{:03d} {}'.format(thousandths // 1000, thousandths % 1000, target)
    result = shown(unit)
    larger = ({'ms': 's'} if not memory else {'B': 'KiB', 'KiB': 'MiB', 'KB': 'MB'}).get(unit)
    if larger and unit == 'B' and value >= MIB: larger = 'MiB'
    if larger and value >= scales[larger]: result += ' (' + shown(larger) + ')'
    return result


class Runner:
    """Reuse one observer for sequential runs without sharing their clocks.

    stdin/stdout/stderr may be None (inherit), file descriptors or open files.
    Caller owns those files. Exceptions are ValueError/OSError; process errors
    remain Result outcomes. Signal handling requires execution on the main
    Python thread, as it does for the command-line application's entry point.
    """

    def __init__(self, timeout_ms="inf", memory_mib="inf", show_time=False,
                 show_memory=False, show_command=False, time_factor='2', memory_factor='2',
                 time_unit='ms', memory_unit='KiB'):
        self.timeout_text, self.memory_text = str(timeout_ms), str(memory_mib)
        self.timeout_ns = _budget(timeout_ms, 1_000_000)
        self.memory_bytes = _budget(memory_mib, MIB)
        self.show_time, self.show_memory = bool(show_time), bool(show_memory)
        self.show_command = bool(show_command)
        self.time_unit, self.memory_unit = time_unit, memory_unit
        format_usage(0, time_unit); format_usage(0, memory_unit, True)
        self.kill_time_ns = self._threshold(self.timeout_ns, time_factor)
        self.kill_memory_bytes = self._threshold(self.memory_bytes, memory_factor)
        self._running = False
        self.on_launch = None  # Set only for the candidate's first visible execution.
        self.sampler = None
        if self.memory_bytes is not None or self.show_memory:
            if sys.platform == "darwin":
                self.sampler = MacMemory()
            elif sys.platform.startswith("linux"):
                self.sampler = LinuxMemory()
            else:
                raise ValueError("RSS measurement requires macOS or Linux")

    @staticmethod
    def _threshold(budget, factor):
        numerator, denominator = _factor(factor)
        return None if budget is None else (budget * numerator + denominator - 1) // denominator

    def display(self, result, label=None, count=1):
        prefix = 'cp-run: ' + (str(label) + ': ' if label else '')
        suffix = ' ({} measured runs)'.format(count) if count > 1 else ''
        if self.show_time:
            print(prefix + 'time: ' + format_usage(result.elapsed_ns, self.time_unit) + suffix, file=sys.stderr)
        if self.show_memory:
            print(prefix + 'peak RSS: ' + format_usage(result.peak_bytes, self.memory_unit, True) + suffix, file=sys.stderr)
        self.diagnostic(result, label)

    def diagnostic(self, result, label=None):
        prefix = 'cp-run: ' + (str(label) + ': ' if label else '')
        if result.verdict == 'TLE':
            print(prefix + 'TLE: ' + format_usage(result.elapsed_ns, 'ms') + ' exceeds ' + self.timeout_text + ' ms', file=sys.stderr)
        if result.verdict == 'MLE':
            print(prefix + 'MLE: ' + format_usage(result.peak_bytes, 'MiB', True) + ' exceeds ' + self.memory_text + ' MiB', file=sys.stderr)

    @staticmethod
    def _fd(stream):
        if stream is None:
            return None
        fd = stream if isinstance(stream, int) else stream.fileno()
        if fd < 0:
            raise ValueError("program streams must be open file descriptors")
        return fd

    def run(self, argv, stdin=None, stdout=None, label=None, stderr=None, report=True):
        """Launch exactly one argv, then measure until that child exits.

        The clock includes OS launch/wait overhead, as an external wall-clock
        command timer does. It excludes this method's stream validation,
        signal setup and display formatting. No observer can promise a zero
        scheduling error; SIGCHLD avoids introducing a fixed polling delay.
        report=False suppresses observer messages; stream redirection remains
        explicit so callers cannot accidentally hide a measured-run error.
        """
        if self._running:
            raise ValueError("Runner cannot execute concurrent/reentrant calls")
        argv = [os.fspath(arg) for arg in argv]
        if not argv or not argv[0]:
            raise ValueError("expected a nonempty program argv")
        input_fd, output_fd, error_fd = self._fd(stdin), self._fd(stdout), self._fd(stderr)
        prefix = "cp-run: " + (str(label) + ": " if label else "")
        if report and self.show_command:
            display = shlex.join(argv)
            for operator, stream in (("<", stdin), (">", stdout), ("2>", stderr)):
                name = getattr(stream, "name", None)
                if isinstance(name, (str, bytes, os.PathLike)):
                    display += " {} {}".format(operator, shlex.quote(os.fsdecode(name)))
            print(display, file=sys.stderr, flush=True)

        # CLOEXEC pipes wake select on SIGCHLD/signals without capturing any
        # program output. All setup happens before the measurement starts.
        reader, writer = os.pipe()
        os.set_blocking(reader, False)
        os.set_blocking(writer, False)
        handlers, old_wakeup = {}, None
        pid, child, outcome, finished_ns = None, None, None, None
        interrupted, interrupt_deadline = 0, None
        collecting, signalling, pending_signal = False, False, 0
        killed, peak, started_ns = False, 0, None
        early_exit = False
        self._running = True

        def send_group(signum):
            nonlocal signalling, pending_signal
            if pid is None or outcome is not None:
                return
            if collecting:
                pending_signal = signum  # wait4 may already have reaped it.
                return
            if signalling:
                return  # A nested signal is covered by the pending deadline.
            denied, group_denied = None, False
            signalling = True
            try:
                # Keep the leader unreaped through this short check+kill
                # section, so its PID cannot become another group's ID.
                if outcome is None:
                    try:
                        os.killpg(pid, signum)
                    except ProcessLookupError:
                        pass
                    except PermissionError as error:
                        group_denied = True
                        # Darwin can reject a zombie-only group before wait4
                        # exposes its leader's exit. Signal our still-unreaped
                        # child directly: its PID cannot yet be reused. A live
                        # child with a genuine permission denial still fails.
                        try:
                            os.kill(pid, signum)
                        except ProcessLookupError:
                            pass
                        except PermissionError:
                            denied = error
            finally:
                signalling = False
            if group_denied:
                # Exit may become waitable only on a later SIGCHLD. A successful
                # direct signal needs no guessed delay or blocking zombie probe.
                collect_exit()
                if denied is not None and outcome is None:
                    raise denied

        def collect_exit():
            nonlocal collecting, outcome, finished_ns, pending_signal
            if pid is None or outcome is not None or collecting or signalling:
                return
            collecting = True  # A Python signal can interrupt a wait4 call.
            try:
                waited, status, usage = os.wait4(pid, os.WNOHANG)
                if waited:
                    finished_ns = time.monotonic_ns()
                    outcome = (status, usage)
            finally:
                collecting = False
                if pending_signal:
                    signum, pending_signal = pending_signal, 0
                    send_group(signum)

        def child_changed(_signum, _frame):
            nonlocal early_exit
            # Record exit promptly, even if SIGCHLD interrupted an RSS sample.
            # The reentrancy guard prevents two wait4 calls reaping one child.
            if pid is None: early_exit = True
            else: collect_exit()

        def forward(signum, _frame):
            nonlocal interrupted, interrupt_deadline
            interrupted = signum
            interrupt_deadline = time.monotonic_ns() + 100_000_000
            send_group(signum)

        try:
            old_wakeup = signal.set_wakeup_fd(writer)
            handlers[signal.SIGCHLD] = signal.signal(signal.SIGCHLD, child_changed)
            for signum in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP, signal.SIGQUIT):
                handlers[signum] = signal.signal(signum, forward)

            # posix_spawn avoids copying an observer's Python address space.
            # Streams stay inherited unless explicitly redirected. A hidden
            # warm-up supplies all three descriptors; measured runs retain
            # the normal stderr contract. report controls observer text only.
            actions = [(os.POSIX_SPAWN_DUP2, fd, target)
                       for fd, target in ((input_fd, 0), (output_fd, 1), (error_fd, 2))
                       if fd is not None and fd != target]
            started_ns = time.monotonic_ns()
            try:
                pid = os.posix_spawnp(argv[0], argv, os.environ,
                                      file_actions=actions, setsid=True)
            except (NotImplementedError, TypeError):
                # Older secondary systems may lack the spawn setsid extension.
                # Keep grouping correct there, even if launch costs more.
                child = subprocess.Popen(argv, stdin=stdin, stdout=stdout, stderr=stderr,
                                         start_new_session=True)
                pid = child.pid
            # A very fast child can exit before posix_spawn returns its PID.
            # Reap immediately, before history I/O: its earlier SIGCHLD could
            # not identify the child, and callback latency is not program time.
            if early_exit: collect_exit()
            if self.on_launch is not None:
                self.on_launch()
            if interrupted:
                forward(interrupted, None)

            while outcome is None:
                # Reap before sampling: completed programs need no extra RSS
                # scan, and their elapsed time must not include its duration.
                collect_exit()
                if outcome is not None:
                    break
                now = time.monotonic_ns()
                if self.sampler is not None and not killed:
                    peak = max(peak, self.sampler.sample(pid))
                if outcome is not None:
                    break
                now = time.monotonic_ns()
                hard_time = (started_ns + self.kill_time_ns
                             if self.kill_time_ns is not None else None)
                force_stop = ((hard_time is not None and now >= hard_time)
                              or (self.memory_bytes is not None
                                  and peak >= self.kill_memory_bytes)
                              or (interrupt_deadline is not None
                                  and now >= interrupt_deadline))
                if force_stop and not killed:
                    send_group(signal.SIGKILL)
                    killed = True
                if outcome is not None:
                    break

                deadlines = [] if killed else [d for d in (
                    hard_time, interrupt_deadline,
                    now + POLL_NS if self.sampler is not None else None,
                ) if d is not None]
                delay = max(0, min(deadlines) - time.monotonic_ns()) / 1e9 if deadlines else None
                ready, _, _ = select.select([reader], [], [], delay)
                if ready:
                    try:
                        os.read(reader, 4096)
                    except BlockingIOError:
                        pass
        except BaseException:
            # Broken accounting must not silently disable a requested limit.
            if pid is not None and outcome is None:
                send_group(signal.SIGKILL)
                while outcome is None:
                    try:
                        waited, status, usage = os.wait4(pid, 0)
                        outcome = (status, usage)
                    except InterruptedError:
                        continue
                    except ChildProcessError:
                        break
            raise
        finally:
            if old_wakeup is not None:
                signal.set_wakeup_fd(old_wakeup)
            for signum, handler in handlers.items():
                signal.signal(signum, handler)
            os.close(reader)
            os.close(writer)
            self._running = False
            if child is not None and outcome is not None:
                child.returncode = os.waitstatus_to_exitcode(outcome[0])

        status, usage = outcome
        elapsed_ns = finished_ns - started_ns
        # Darwin's kernel reports peak RSS in bytes; Linux reports KiB. Kernel
        # accounting catches a brief leader allocation between group samples.
        peak = max(peak, int(usage.ru_maxrss) * (1 if sys.platform == "darwin" else 1024))
        returncode = os.waitstatus_to_exitcode(status)
        native_status = returncode if returncode >= 0 else 128 - returncode
        # User cancellation is an interruption, not a candidate wrong answer.
        # Otherwise nominal budgets decide verdicts, independently of grace.
        if interrupted:
            result = Result(128 + interrupted, elapsed_ns, peak, 'INTERRUPTED')
        elif self.timeout_ns is not None and elapsed_ns > self.timeout_ns:
            result = Result(124, elapsed_ns, peak, 'TLE')
        elif self.memory_bytes is not None and peak > self.memory_bytes:
            result = Result(125, elapsed_ns, peak, 'MLE')
        else:
            result = Result(native_status, elapsed_ns, peak, 'OK' if native_status == 0 else 'RTE')
        if report: self.display(result, label)
        return result


# Source: measurements.py
"""Repeated runs reuse one supervisor and expose one visible stdout only."""

from contextlib import ExitStack
import stat
import tempfile


def repetition_count(value):
    text = str(value)
    if not text.isascii() or not text.isdecimal() or len(text) > 6:
        raise ValueError('average must be an integer from 0 to 100000')
    number = int(text)
    if number > 100000: raise ValueError('average must not exceed 100000')
    return max(1, number)


def run_series(runner, config, launch, validate=None, label=None):
    """Warm once, then aggregate valid executions; failures never disappear in a median."""
    config['_series_runs'] = 0
    observed = bool(config.get('show_time') or config.get('show_memory'))
    count = repetition_count(config.get('average', 1)) if observed else 1
    if observed and config.get('warmup'):
        warm = launch(-1)
        if warm.verdict in ('INTERRUPTED', 'TLE', 'MLE') or ((config.get('operation') in ('test', 'stress') or config.get('_strict_warmup')) and warm.status):
            if config.get('operation') not in ('test', 'stress'): runner.diagnostic(warm, label)
            return warm
    durations, peak, result = [], 0, None
    for index in range(count):
        result = launch(index)
        config['_series_runs'] = index + 1
        durations.append(result.elapsed_ns); peak = max(peak, result.peak_bytes)
        if not result.status and validate is not None:
            verdict = validate(index)
            if verdict:
                result = Result(4 if verdict == 'INCOMPLETE' else 3,
                                result.elapsed_ns, result.peak_bytes, verdict)
        if result.status: break
    if not result.status:
        durations.sort(); middle = len(durations) // 2
        median = durations[middle] if len(durations) % 2 else (durations[middle - 1] + durations[middle] + 1) // 2
        result = Result(0, median, peak, 'OK')
    else:
        result = Result(result.status, result.elapsed_ns, peak, result.verdict)
    if config.get('operation') not in ('test', 'stress'): runner.display(result, label, len(durations))
    return result


def record_terminal_input(runner, argv, recording, maximum):
    """Run visibly while teeing terminal input to a bounded replay file.

    The relay reads only while the child runs, so a program needing no input
    never waits for terminal EOF. A stop pipe wakes it immediately on exit or
    cancellation. Only this explicit repeated-TTY path starts a helper thread.
    """
    import threading

    failures = []
    with ExitStack() as stack:
        reader_fd, writer_fd = os.pipe()
        incoming = stack.enter_context(os.fdopen(reader_fd, 'rb', buffering=0))
        outgoing = stack.enter_context(os.fdopen(writer_fd, 'wb', buffering=0))
        stop_reader, stop_writer = os.pipe()
        stack.callback(os.close, stop_reader)
        stack.callback(os.close, stop_writer)
        os.set_blocking(writer_fd, False)

        def relay():
            pending, copied = b'', 0
            try:
                while True:
                    readable, writable, _ = select.select(
                        [stop_reader] + ([] if pending else [0]),
                        [writer_fd] if pending else [], [], None)
                    if stop_reader in readable:
                        return
                    if 0 in readable:
                        block = os.read(0, 65536)
                        if not block:
                            return
                        copied += len(block)
                        if copied > maximum:
                            raise CheckSetupError('replayed input exceeds spool byte limit')
                        recording.write(block)
                        pending = block
                    if writer_fd in writable:
                        try:
                            pending = pending[os.write(writer_fd, pending):]
                        except BlockingIOError:
                            continue
            except BrokenPipeError:
                pass  # Child exited or deliberately closed stdin.
            except BaseException as error:
                failures.append(error)
            finally:
                outgoing.close()  # Deliver EOF when the terminal supplied EOF.

        thread = threading.Thread(target=relay, name='cp-run-input', daemon=True)
        thread.start()
        try:
            result = runner.run(argv, stdin=incoming, report=False)
        finally:
            os.write(stop_writer, b'!')
            thread.join()
        if failures:
            raise failures[0]
        recording.flush()
        recording.seek(0)
        return result


def replay_stderr(source):
    """Replay a failed hidden run byte-for-byte without buffering it in RAM."""
    source.seek(0)
    with os.fdopen(os.dup(2), 'wb') as destination:
        shutil.copyfileobj(source, destination)


def supervise(config):
    """One visible run; copied input and hidden repetitions share one observer."""
    runner = _runner(config)
    argv = [*config.get('main_argv', [config['executable']]), *config.get('runtime_args', [])]
    observed = bool(config.get('show_time') or config.get('show_memory'))
    count = repetition_count(config.get('average', 1)) if observed else 1
    with ExitStack() as stack:
        sink = stack.enter_context(open(os.devnull, 'wb'))
        errors = stack.enter_context(tempfile.TemporaryFile())
        replay, replay_offset, captured_terminal = None, 0, False
        if observed or count > 1 or str(config.get('timeout_ms', 'inf')) != 'inf' or str(config.get('memory_mib', 'inf')) != 'inf':
            maximum = positive_setting(config.get('max_spool', 268435456), 'spool limit')
            if os.isatty(0):
                replay = stack.enter_context(tempfile.TemporaryFile())
                if config.get('show_command'):
                    print(shlex.join(argv), file=sys.stderr, flush=True)
                runner.on_launch = lambda: remember_launch(config)
                print('cp-run: enter all input, then press Ctrl-D on an empty line to start timing.', file=sys.stderr, flush=True)
                copied = 0
                while True:
                    block = os.read(0, 65536)
                    if not block:
                        break
                    copied += len(block)
                    if copied > maximum:
                        raise CheckSetupError('replayed input exceeds spool byte limit')
                    replay.write(block)
                replay.seek(0)
                if observed:
                    initial = runner.run(argv, stdin=replay, report=False)
                    if initial.status:
                        runner.diagnostic(initial)
                        return initial.status
                    captured_terminal = True
            else:
                source = stack.enter_context(os.fdopen(os.dup(0), 'rb'))
                if stat.S_ISREG(os.fstat(0).st_mode):
                    replay = source; replay_offset = source.tell()
                else:
                    replay = stack.enter_context(tempfile.TemporaryFile())
                    copied = 0
                    while True:
                        block = source.read(65536)
                        if not block: break
                        copied += len(block)
                        if copied > maximum: raise CheckSetupError('replayed input exceeds spool byte limit')
                        replay.write(block)
        # Ordinary warm-ups now receive the same recorded data as measurements;
        # every nonzero execution must stop the series and expose its stderr.
        series_config = dict(config, _strict_warmup=True)

        def launch(index):
            if replay is not None:
                replay.seek(replay_offset); incoming = replay
            else:
                incoming = None
            visible = index == 0 and not captured_terminal
            if visible and config.get('show_command'):
                print(shlex.join(argv), file=sys.stderr, flush=True)
            runner.on_launch = (lambda: remember_launch(config)) if index >= 0 else None
            errors.seek(0); errors.truncate()
            result = runner.run(argv, stdin=incoming, stdout=None if visible else sink,
                                stderr=None if visible else errors, report=False)
            if not visible and result.status:
                replay_stderr(errors)
            return result
        return run_series(runner, series_config, launch).status


def run_candidate(runner, config, argv, incoming, outgoing, answer, label):
    """Check every repeat; preserve a failing repeat for useful diagnostics/replay."""
    hidden = Path(outgoing).with_name('repeat.stdout')
    comparisons = []
    config['_stderr_paths'] = []; config.pop('_failed_output', None)
    config.pop('_failed_repeat', None)
    with open(os.devnull, 'wb') as sink:
        def launch(index):
            target = outgoing if index == 0 else hidden
            if index >= 0: _show_run(config, argv, incoming, target)
            runner.on_launch = (lambda: remember_launch(config)) if index >= 0 else None
            stderr_path = Path(outgoing).with_name('stderr-{}.txt'.format(index))
            config['_stderr_paths'].append(('warm-up' if index < 0 else 'run {}'.format(index + 1), str(stderr_path)))
            with open(incoming, 'rb') as stdin, open(target, 'wb') as stdout, open(stderr_path, 'wb') as stderr:
                result = runner.run(argv, stdin=stdin, stdout=stdout, stderr=stderr, report=False)
            if index > 0 and result.status:
                config['_failed_output'] = str(hidden); config['_failed_repeat'] = index + 1
            return result
        def validate(index):
            target = outgoing if index == 0 else hidden
            comparison = compare_case(target, answer, config)
            if index == 0 or not comparisons: comparisons[:] = [comparison]
            if not comparison.equal:
                if index > 0:
                    config['_failed_output'] = str(hidden); config['_failed_repeat'] = index + 1
                return 'INCOMPLETE' if comparison.incomplete else 'WA'
            return None
        result = run_series(runner, config, launch, validate, label)
    if not Path(outgoing).exists(): Path(outgoing).touch()
    if not config.get('_failed_output'): hidden.unlink(missing_ok=True)
    comparison = comparisons[-1] if comparisons else None
    return result, comparison


# Source: cases.py
"""Answer checking and reproducible stress tests, embedded in cp-run.zsh.

This module shares Runner with runtime.py. It never compiles, evaluates shell
text. The checking layer owns stderr capture and reports; the shell prepares
launch targets before execution.
"""

import base64
from collections import deque
from contextlib import contextmanager
from dataclasses import dataclass
import fcntl
import hashlib
import io
import json
import os
from pathlib import Path
import shlex
import shutil
import sys
import tempfile


class CheckUsageError(ValueError):
    """A malformed request; the CLI adapter prints one diagnostic/status 2."""


class CheckSetupError(OSError):
    """Files or infrastructure failed independently of the tested solution."""


def decode_separator(value):
    """Accept literal LF or visible \\n; deliberately decode no other escapes."""
    text = str(value).replace(r"\n", "\n").replace(r"\x1e", "\x1e")
    allowed = "\n\x1e #=_.:+-abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    if not text or text[0] != "\n" or text[-1] != "\n" or any(c not in allowed for c in text):
        raise CheckUsageError("--sep must start/end with LF and contain only LF, ASCII letters, digits, spaces or #=_.:+-")
    return text.encode("ascii")


def split_cases(payload, separator):
    """Drop one terminal terminator, preserving deliberate empty test blocks."""
    blocks = payload.split(separator)
    if payload.endswith(separator):
        blocks.pop()
    return blocks or [b""]


def positive_setting(value, label):
    text = str(value)
    if not text.isascii() or not text.isdecimal() or len(text) > 12 or int(text) <= 0:
        raise CheckUsageError(label + " must be a positive integer (up to 12 digits)")
    return int(text)


def _frame_console(stream, outputs, maximum=268435456):
    """Copy framed console bytes in bounded chunks, including very long rows."""
    if getattr(stream, 'isatty', lambda: False)():
        print('Input, then :::answer::: on its own line, then answer and EOF:', file=sys.stderr)
    source = stream.buffer if hasattr(stream, 'buffer') else stream
    side, total, at_start = 0, 0, True
    while True:
        line = source.readline(65536)
        if not line: break
        if isinstance(line, str): line = line.encode()
        total += len(line)
        if total > maximum: raise CheckSetupError('console input exceeds spool byte limit')
        body = line[:-1] if line.endswith(b'\n') else line
        if body.endswith(b'\r'): body = body[:-1]
        if at_start and body == b':::answer:::':
            if side: raise CheckUsageError('--cin requires exactly one :::answer::: marker line')
            side = 1
        else:
            if at_start and body == b'\\:::answer:::': line = line[1:]
            outputs[side].write(line)
        at_start = line.endswith(b'\n')
    if not side: raise CheckUsageError('--cin requires an :::answer::: marker line')


def console_payloads(stream):
    """Small in-memory convenience API; the CLI spools directly to files."""
    outputs = (io.BytesIO(), io.BytesIO())
    _frame_console(stream, outputs)
    return tuple(output.getvalue() for output in outputs)


@dataclass(frozen=True)
class CaseSlice:
    """A byte range in a regular file, copied without loading the whole case."""
    path: str
    start: int
    length: int

    def copy_to(self, destination):
        with open(self.path, 'rb') as source, open(destination, 'wb') as output:
            source.seek(self.start)
            remaining = self.length
            while remaining:
                block = source.read(min(65536, remaining))
                if not block: raise CheckSetupError('test data changed or was truncated: ' + self.path)
                output.write(block); remaining -= len(block)


def index_cases(path, separator=None, start_offset=0, keep_terminal=False):
    """Index nonoverlapping delimiters across chunks; drop one terminal delimiter."""
    path = str(Path(path).resolve())
    if not Path(path).is_file(): raise CheckSetupError('test file not found or not regular: ' + path)
    if separator is None: return [CaseSlice(path, 0, Path(path).stat().st_size)]
    ranges, pending, base, start = [], b'', start_offset, start_offset
    with open(path, 'rb') as stream:
        stream.seek(start_offset)
        while True:
            block = stream.read(65536)
            if not block: break
            pending += block
            while True:
                found = pending.find(separator)
                if found < 0: break
                end = base + found
                ranges.append(CaseSlice(path, start, end - start))
                if len(ranges) > 100000: raise CheckSetupError('test bundle exceeds 100000 cases')
                consumed = found + len(separator)
                start = base + consumed
                pending = pending[consumed:]; base += consumed
            keep = min(len(pending), len(separator) - 1)
            discard = len(pending) - keep
            pending = pending[discard:]; base += discard
    size = base + len(pending)
    if keep_terminal or start < size or not ranges: ranges.append(CaseSlice(path, start, size - start))
    return ranges


def _console_paths(config):
    """Persist only filenames, never base64 copies of the complete test bundle."""
    cache = config.get('console_cache')
    if not cache: raise CheckUsageError('--cin requires a private console cache')
    cache = Path(cache)
    incoming, answer = str(cache) + '.input', str(cache) + '.answer'
    if not cache.exists():
        with open(incoming, 'xb') as left, open(answer, 'xb') as right:
            _frame_console(sys.stdin, (left, right), positive_setting(config.get('max_spool', 268435456), 'spool limit'))
        with cache.open('x') as record: json.dump({'input': incoming, 'answer': answer}, record)
    return json.loads(cache.read_text())


def _same_path(left, right):
    a, b = Path(left), Path(right)
    if a.resolve() == b.resolve():
        return True
    try:
        return a.exists() and b.exists() and os.path.samefile(a, b)
    except OSError:
        return False


def _validate_paths(config):
    """Protect every readable role before creating any report/output artifact."""
    operation = config.get("operation", "test")
    protected = [str(p) for p in config.get("protected", []) if p]
    protected.extend(str(config[key]) for key in ("executable", "brute", "generator") if config.get(key))
    reads = []
    if operation == "test" and not config.get("cin"):
        reads = config.get("case_reads") if config.get("mult") else [config.get("input", "in.txt"), config.get("answer", "ans.txt")]
        reads = reads or []
        if len(reads) == 2 and _same_path(*reads):
            raise CheckUsageError("test input and answer must be different files")
        for path in reads:
            if not Path(path).is_file():
                raise CheckSetupError("test file not found or not regular: " + str(path))
            if any(_same_path(path, other) for other in protected):
                raise CheckUsageError("test data must not alias a source or executable: " + str(path))
    # The CLI expands workspace anchors before transport; validate the selected
    # result path alongside the report, source, binary and every input/answer.
    actual = Path(config.get("actual", "out.txt")).absolute()
    config["actual"] = str(actual)
    writes = [str(actual)]
    if not config.get("cout"):
        writes.append(str(config.get("report", "test_out")))
    for index, path in enumerate(writes):
        candidate = Path(path)
        if candidate.is_symlink() or candidate.is_dir():
            raise CheckUsageError("test output must be a regular path, not a symlink/directory: " + path)
        if not candidate.parent.is_dir():
            raise CheckSetupError("test output directory does not exist: " + str(candidate.parent))
        if any(_same_path(path, other) for other in protected + reads + writes[:index]):
            raise CheckUsageError("test output would overwrite another role: " + path)


@dataclass
class CheckPlan:
    inputs: list
    answers: list
    selected: list
    separator: bytes
    line_limit: int
    zero_notice: bool = False
    ids: list = None


def _prepare_check(config):
    operation = config.get("operation", "test")
    separator = decode_separator(config.get("sep", r"\n\n"))
    line_limit = positive_setting(config.get("line_limit", 10000), "NUM_LINE_LIMIT")
    maximum = config.get("num_test")
    if maximum is not None:
        maximum = positive_setting(maximum, "--test-iters")
    if operation == "stress":
        if config.get("cin"):
            raise CheckUsageError("--cin is not supported by stress; use test --cin")
        positive_setting(config.get("iterations", 1000), "stress iterations")
        seed = config.get("seed")
        if seed is not None and (not str(seed).isascii() or not str(seed).isdecimal()
                                 or len(str(seed)) > 20 or not 0 <= int(seed) < 2**64):
            raise CheckUsageError("--seed must be an unsigned 64-bit integer")
        _validate_paths(config)
        return CheckPlan([], [], [], separator, line_limit)
    # Discover and validate the complete suite before selection or compilation.
    ids = None
    if config.get('mult'):
        if config.get('cin'): raise CheckUsageError('--cin is unavailable with mult files')
        ids, inputs, answers = mult_cases(config)
        config['case_reads'] = [case.path for case in (*inputs, *answers)]
    else:
        paths = _console_paths(config) if config.get('cin') else {
            'input': config.get('input', 'in.txt'), 'answer': config.get('answer', 'ans.txt')}
        auto = bool(config.get('auto'))
        reader = counted_cases if auto and config.get('bundle_format') == 'counted' else index_cases
        inputs = reader(paths['input'], separator if auto else None)
        answers = reader(paths['answer'], separator if auto else None)
    if len(inputs) != len(answers):
        raise CheckUsageError('test count mismatch: input has {} cases; answer has {}'.format(len(inputs), len(answers)))
    if not inputs: raise CheckUsageError('test suite is empty')
    ids = ids or list(range(1, len(inputs) + 1))
    available = set(ids)
    requested = config.get('cases', [])
    independent = config.get('auto') or config.get('mult')
    if requested and not independent: raise CheckUsageError('case numbers require test=auto or test=mult')
    selected, zero = [], False
    for value in requested:
        try: number = int(value)
        except (ValueError, TypeError): raise CheckUsageError('test case numbers must be integers') from None
        if number == 0: number, zero = 1, True
        if number not in available: raise CheckUsageError('test number {} is not available'.format(number))
        if number not in selected: selected.append(number)
    selected = selected or ids
    if maximum is not None and independent: selected = selected[:maximum]
    _validate_paths(config)
    return CheckPlan(inputs, answers, selected, separator, line_limit, zero, ids)


def preflight_check(config):
    """Count/validate cases before compilation; console is spooled only once."""
    return _prepare_check(config)


def _load_plan(config):
    return _prepare_check(config)


@contextmanager
def check_lock():
    """Lock the directory inode: no stale PID file or persistent config sidecar."""
    descriptor = os.open(".", os.O_RDONLY)
    try:
        try:
            fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise CheckSetupError("another test/stress run is writing results in this directory") from None
        yield
    finally:
        os.close(descriptor)



# Source: test_layout.py
"""Fixed numbered test files and a shared, contained test-data writer."""

import re


WORKSPACE_PATH_PREFIX = "{wsp-dir}"


def workspace_path_suffix(value):
    """Validate the literal root prefix without needing a workspace at save time."""
    if WORKSPACE_PATH_PREFIX not in value:
        return None
    prefix = WORKSPACE_PATH_PREFIX + "/"
    if value == WORKSPACE_PATH_PREFIX:
        return ""
    if not value.startswith(prefix):
        raise CheckUsageError("use {wsp-dir}/PATH at the beginning of a path")
    relative = value[len(prefix):]
    if not relative or WORKSPACE_PATH_PREFIX in relative or Path(relative).is_absolute() or ".." in Path(relative).parts:
        raise CheckUsageError("workspace path must stay inside its workspace")
    return relative


def layout_root(config):
    """Resolve the one task folder; artifact routing never changes test data."""
    folder = _settings_test_folder(config.get("test_folder", "{wsp-dir}/tests"))
    relative = workspace_path_suffix(folder)
    if relative is None:
        return Path(folder).absolute()
    workspace = Path(config.get("workspace", ".")).resolve()
    target = workspace / relative
    try:
        target.resolve().relative_to(workspace)
    except ValueError:
        raise CheckUsageError("test folder escapes workspace") from None
    return target


def test_filename(stream, number):
    """The public layout is fixed: in1.txt/ans1.txt, with positive case IDs."""
    return "{}{}.txt".format(stream, number)


def contained_target(root, relative):
    """Reject symlink parents before writes, including links back inside root."""
    root = Path(root).absolute()
    if root.is_symlink():
        raise CheckUsageError("test root must not be a symbolic link")
    root = root.resolve()
    relative = Path(relative)
    if relative.is_absolute() or ".." in relative.parts:
        raise CheckUsageError("test path escapes its root")
    candidate = root / relative
    for item in (candidate, *candidate.parents):
        if item == root:
            break
        if item.is_symlink():
            raise CheckUsageError("test path contains a symbolic link: " + str(item))
    try:
        candidate.resolve().relative_to(root.resolve())
    except ValueError:
        raise CheckUsageError("test path escapes its root") from None
    return candidate


def discover_cases(root, stream):
    """Read only this folder; gaps are allowed, ambiguous numeric IDs are not."""
    root = Path(root)
    if not root.is_dir():
        raise CheckSetupError("test folder not found: " + str(root))
    expression = re.compile(re.escape(stream) + r"([0-9]+)\.txt")
    result = {}
    for path in root.iterdir():
        match = expression.fullmatch(path.name)
        if not match:
            continue
        digits = match[1]
        if len(digits) > 12 or int(digits) < 1:
            raise CheckUsageError("test IDs must be positive integers")
        number = int(digits)
        if number in result:
            raise CheckUsageError("duplicate numerical test ID: " + digits)
        if len(result) >= 100000:
            raise CheckSetupError("test folder exceeds 100000 cases")
        target = contained_target(root, path.name)
        if not target.is_file():
            raise CheckSetupError("test is not a regular file: " + str(target))
        result[number] = target
    return result


def mult_cases(config):
    root = layout_root(config)
    left, right = discover_cases(root, "in"), discover_cases(root, "ans")
    if not left or set(left) != set(right):
        raise CheckUsageError(
            "mult test ID mismatch: missing answers {}; missing inputs {}".format(
                sorted(set(left) - set(right)), sorted(set(right) - set(left))
            )
        )
    ids = sorted(left)
    return ids, [index_cases(left[n])[0] for n in ids], [index_cases(right[n])[0] for n in ids]


def write_test_files(root, entries, overwrite=False, protected=()):
    """Preflight the set, stage sibling files, and roll back handled failures.

    Each replacement is atomic. A set in an existing directory is deliberately
    not advertised as crash-atomic. The directory lock coordinates our writers.
    """
    root = Path(root).absolute()
    if root.is_symlink():
        raise CheckUsageError("test root must not be a symbolic link")
    root = root.resolve()
    planned, names, identities = [], set(), set()
    for relative, content in entries:
        target = contained_target(root, relative)
        identity = (target.stat().st_dev, target.stat().st_ino) if target.exists() else None
        if (
            target in names
            or (identity is not None and identity in identities)
            or any(_same_path(target, p) for p in protected)
        ):
            raise CheckUsageError("test output aliases another protected role: " + str(target))
        names.add(target)
        if identity is not None:
            identities.add(identity)
        if target.exists():
            if not target.is_file():
                raise CheckUsageError("test output is not a regular file: " + str(target))
            if target.stat().st_size == len(content) and target.read_bytes() == content:
                continue
            if not overwrite:
                raise CheckUsageError("test file exists; use --overwrite: " + str(target))
        planned.append((target, content))
    root.mkdir(parents=True, exist_ok=True)
    descriptor = os.open(root, os.O_RDONLY)
    staged, previous, installed = [], {}, []
    try:
        try:
            fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise CheckSetupError("another import is writing this test directory") from None
        for target, content in planned:
            # Recheck after the lock; another process may have committed meanwhile.
            contained_target(root, target.relative_to(root))
            if (
                target.exists()
                and not overwrite
                and (target.stat().st_size != len(content) or target.read_bytes() != content)
            ):
                raise CheckUsageError("test file appeared during import: " + str(target))
            target.parent.mkdir(parents=True, exist_ok=True)
            with tempfile.NamedTemporaryFile(
                dir=target.parent, prefix=".cp-run-import-", delete=False
            ) as stream:
                staged.append((Path(stream.name), target))
                stream.write(content)
                stream.flush()
                os.fsync(stream.fileno())
            if target.exists():
                with tempfile.NamedTemporaryFile(
                    dir=target.parent, prefix=".cp-run-backup-", delete=False
                ) as backup:
                    previous[target] = Path(backup.name)
                shutil.copy2(target, previous[target])
                os.chmod(staged[-1][0], stat.S_IMODE(target.stat().st_mode))
        for source, target in staged:
            installed.append(
                target
            )  # Register before replace: interruption between bytecodes is recoverable.
            os.replace(source, target)
    except BaseException:
        for target in reversed(installed):
            if target in previous:
                os.replace(previous[target], target)
            else:
                target.unlink(missing_ok=True)
        raise
    finally:
        for source, _ in staged:
            source.unlink(missing_ok=True)
        for backup in previous.values():
            backup.unlink(missing_ok=True)
        os.close(descriptor)


# Source: bundles.py
"""Lossless counted bundles shared by pack, unpack and counted auto tests."""


def counted_cases(filename, separator):
    if not Path(filename).is_file():
        raise CheckSetupError("bundle is not a regular file: " + str(filename))
    with open(filename, "rb") as source:
        header = source.readline(16)
        if not header.endswith(b"\n") or not header[:-1].isdigit() or len(header) > 7:
            raise CheckUsageError("bundle needs a decimal case count on its first line")
        count = int(header[:-1])
        if count > 100000:
            raise CheckUsageError("bundle exceeds 100000 cases")
        offset = source.tell()
    if not count:
        if Path(filename).stat().st_size != offset:
            raise CheckUsageError("zero-case bundle contains data")
        return []
    cases = index_cases(filename, separator, start_offset=offset, keep_terminal=True)
    if len(cases) != count:
        raise CheckUsageError(
            "bundle count mismatch: header {}; found {}".format(count, len(cases))
        )
    return cases


def slice_bytes(case, maximum=268435456):
    if case.length > maximum:
        raise CheckSetupError("case exceeds conversion byte limit")
    with open(case.path, "rb") as source:
        source.seek(case.start)
        data = source.read(case.length)
    if len(data) != case.length:
        raise CheckSetupError("test data changed during conversion")
    return data


def encode_bundle(records, separator, maximum=268435456):
    """Verify framing before any write, including partial-marker overlaps."""
    total = sum(map(len, records)) + max(0, len(records) - 1) * len(separator)
    if total > maximum:
        raise CheckSetupError("bundle exceeds conversion byte limit")
    if separator == b"\n\x1e\n" and any(b"\x1e" in case for case in records):
        raise CheckUsageError("test contains reserved RS byte; choose another --sep")
    payload = separator.join(records)
    decoded = payload.split(separator) if records else []
    if decoded != records:
        raise CheckUsageError(
            "separator collides with test data or its boundary; choose another separator"
        )
    return str(len(records)).encode("ascii") + b"\n" + payload


def execute_bundle(config):
    """Pack both streams by default; preflight all outputs before changing any."""
    operation = config["operation"]
    selected = config.get("bundle_stream", "both")
    if selected not in ("both", "in", "ans"):
        raise CheckUsageError("pack/unpack accepts =in, =ans, or no selector for both")
    streams = ("in", "ans") if selected == "both" else (selected,)
    paths = {"in": Path(config.get("default_input", "in.txt")).absolute(),
             "ans": Path(config.get("default_answer", "ans.txt")).absolute()}
    root = layout_root(config)
    separator = decode_separator(config.get("sep", r"\n\x1e\n"))
    maximum = positive_setting(config.get("max_spool", 268435456), "conversion byte limit")
    overwrite = bool(config.get("overwrite"))
    protected = list(config.get("protected", []))
    counts, entries = {}, []
    if operation == "pack":
        discovered = {stream: discover_cases(root, stream) for stream in streams}
        if selected == "both" and set(discovered["in"]) != set(discovered["ans"]):
            raise CheckUsageError("pack input/answer test IDs differ")
        for stream, found in discovered.items():
            if not found:
                raise CheckUsageError("no {} tests to pack in {}".format(stream, root))
            protected.extend(found.values())
            records, total = [], 0
            for number in sorted(found):
                case = index_cases(found[number])[0]
                total += case.length
                if total > maximum:
                    raise CheckSetupError("bundle exceeds conversion byte limit")
                records.append(slice_bytes(case, maximum))
            entries.append((paths[stream], encode_bundle(records, separator, maximum)))
            counts[stream] = len(records)
            if sorted(found) != list(range(1, len(found) + 1)):
                print("cp-run: packed IDs {} as 1..{}".format(sorted(found), len(found)), file=sys.stderr)
        # One preflight/rollback transaction covers both containers, even when
        # their parent directories differ. Common-root paths stay literal.
        common = Path(os.path.commonpath([str(path.parent) for path, _ in entries]))
        write_test_files(common, [(path.relative_to(common), data) for path, data in entries], overwrite, protected)
    else:
        protected.extend(paths[stream] for stream in streams)
        for stream in streams:
            cases = counted_cases(paths[stream], separator)
            if sum(case.length for case in cases) > maximum:
                raise CheckSetupError("bundle exceeds conversion byte limit")
            entries.extend((test_filename(stream, i), slice_bytes(case, maximum))
                           for i, case in enumerate(cases, 1))
            counts[stream] = len(cases)
        if selected == "both" and counts["in"] != counts["ans"]:
            raise CheckUsageError("unpack input/answer counts differ")
        # Reject stale numbered files instead of silently mixing problem sets.
        if root.is_dir():
            for stream in streams:
                if set(discover_cases(root, stream)) - set(range(1, counts[stream] + 1)):
                    raise CheckUsageError("existing extra tests would remain; choose a clean test folder")
        write_test_files(root, entries, overwrite, protected)
    for stream in streams:
        print("cp-run: {} {}: {} cases; folder {}; bundle {}".format(
            operation, stream, counts[stream], root, paths[stream]), file=sys.stderr)
    return 0


# Source: comparison.py
"""Bounded binary comparisons and readable diagnostics."""

class ComparisonLimit(ValueError):
    """An unfinished comparison is never an equality or wrong-answer verdict."""


def _line_values(stream, max_line=1048576, counter=None, max_bytes=67108864):
    """Read one row at a time; a conventional final LF adds no phantom row."""
    number = 0
    while True:
        line = stream.readline(max_line + 1)
        if not line: return
        number += 1
        if len(line) > max_line: raise ComparisonLimit('row exceeds {} bytes'.format(max_line))
        if counter is not None:
            counter[0] += len(line)
            if counter[0] > max_bytes: raise ComparisonLimit('checked data exceeds {} bytes'.format(max_bytes))
        if line.endswith(b"\n"):
            line = line[:-1]
            if line.endswith(b"\r"):
                line = line[:-1]
        yield number, line


@dataclass
class Comparison:
    equal: bool
    incomplete: bool
    used: int
    actual_different: set
    answer_different: set
    missing_rows: list
    reason: str = ''


def compare_streams(actual, answer, budget, max_line=1048576, max_bytes=67108864):
    """Linear bounded-lookahead alignment; never run a quadratic whole-file diff."""
    left, right = deque(), deque()
    counter = [0]
    sources = (iter(_line_values(actual, max_line, counter, max_bytes)),
               iter(_line_values(answer, max_line, counter, max_bytes)))
    exhausted = [False, False]
    changed_left, changed_right, missing = set(), set(), []
    used = 0

    def fill(index, queue):
        while len(queue) < 16 and not exhausted[index]:
            try:
                queue.append(next(sources[index]))
            except StopIteration:
                exhausted[index] = True

    while True:
        try:
            fill(0, left); fill(1, right)
        except ComparisonLimit as error:
            return Comparison(False, True, used, changed_left, changed_right, missing, str(error))
        if not left and not right:
            return Comparison(not (changed_left or changed_right or missing), False,
                              used, changed_left, changed_right, missing)
        if used >= budget:
            return Comparison(False, True, used, changed_left, changed_right, missing)
        used += 1
        if left and right and left[0][1] == right[0][1]:
            left.popleft(); right.popleft(); continue
        # A nearby matching anchor distinguishes insertion/deletion without
        # losing either file's independent original line numbers.
        skip_left = next((i for i, row in enumerate(left) if i and right and row[1] == right[0][1]), None)
        skip_right = next((i for i, row in enumerate(right) if i and left and row[1] == left[0][1]), None)
        if left and (not right or (skip_left is not None and (skip_right is None or skip_left <= skip_right))):
            number, _ = left.popleft(); changed_left.add(number); missing.append((number, None))
        elif right and (not left or skip_right is not None):
            number, _ = right.popleft(); changed_right.add(number); missing.append((None, number))
        else:
            number, _ = left.popleft(); changed_left.add(number)
            number, _ = right.popleft(); changed_right.add(number)


def _quoted(value):
    # ASCII JSON escapes keep ANSI, bidi and invalid UTF-8 bytes inert in files
    # and terminals. Visible escaped Unicode is preferable to spoofed reports.
    return json.dumps(value.decode("utf-8", errors="backslashreplace"), ensure_ascii=True)


def _section(report, title, path, different=None, display_limit=10000):
    report.emit(title + ":")
    if not report.detail_remaining:
        report.emit("  ... display omitted after diagnostic limit; raw data retained")
        return
    found = False
    with open(path, "rb") as stream:
        try:
            rows = _line_values(stream, report.max_line)
            for number, line in rows:
                found = True
                if number > display_limit:
                    report.detail('  ... display truncated; raw data retained')
                    break
                mark = '!' if different and number in different else ' '
                # Clip before escaping: JSON encoding can expand every byte.
                allowance = max(0, report.detail_remaining // 6 - 100)
                clipped = line[:allowance]
                report.detail('  {} {}:{} | {}{}'.format(mark, title, number, _quoted(clipped),
                              ' ... [truncated]' if len(clipped) < len(line) else ''))
                if not report.detail_remaining: break
        except ComparisonLimit as error:
            report.detail('  ... ' + str(error) + '; raw data retained')
    if not found:
        report.emit("  <empty>")
    elif Path(path).stat().st_size:
        with open(path, 'rb') as ending:
            ending.seek(-1, 2)
            if ending.read(1) != b'\n': report.detail('  [no final newline]')


def _failure_details(report, incoming, actual, answer, comparison, display_limit, actual_label="out.txt"):
    report.detail_remaining = report.max_details
    display_limit = report.display_lines
    if comparison.reason: report.emit('INCOMPLETE: ' + comparison.reason)
    _section(report, "input", incoming, display_limit=display_limit)
    _section(report, actual_label, actual, comparison.actual_different, display_limit)
    _section(report, "ans", answer, comparison.answer_different, display_limit)
    for left, right in comparison.missing_rows:
        if left is None:
            report.detail("  ! {}:— | <missing line>; ans:{}".format(actual_label, right))
        if right is None:
            report.detail("  ! ans:— | <missing line>; {}:{}".format(actual_label, left))


def compare_case(actual, answer, config):
    with open(actual, 'rb') as left, open(answer, 'rb') as right:
        return compare_streams(left, right, positive_setting(config.get('line_limit', 10000), 'line limit'),
                               positive_setting(config.get('max_line', 1048576), 'row byte limit'),
                               positive_setting(config.get('max_check', 67108864), 'checked byte limit'))




# Source: reporting.py
"""Readable checking protocols; file and console share the same renderer."""


class Protocol:
    """Keep report commits atomic and preserve a copy for stress failure bundles."""

    def __init__(self, config):
        self.max_line = positive_setting(config.get("max_line", 1048576), "row byte limit")
        self.max_details = positive_setting(config.get("max_report", 262144), "report byte limit")
        self.display_lines = positive_setting(config.get("report_lines", 10000), "report row limit")
        self.detail_remaining = self.max_details
        self.console = bool(config.get("cout"))
        self.destination = Path(config.get("report", "test_out"))
        directory = self.destination.parent if not self.console else Path.cwd()
        handle = tempfile.NamedTemporaryFile(
            mode="w+", encoding="utf-8", dir=directory, prefix=".cp-run-report-", delete=False
        )
        self.stream, self.path = handle, Path(handle.name)

    def emit(self, text=""):
        self.stream.write(text + "\n")
        if self.console:
            print(text, flush=True)

    def detail(self, text):
        """Count encoded diagnostics, not source bytes that can expand on escaping."""
        size = len((text + "\n").encode("utf-8"))
        if size > self.detail_remaining:
            if self.detail_remaining:
                self.emit("  ... diagnostic byte limit reached; raw data retained")
            self.detail_remaining = 0
            return
        self.detail_remaining -= size
        self.emit(text)

    def finish(self):
        self.stream.flush()
        self.stream.close()
        if self.console:
            self.path.unlink(missing_ok=True)
        else:
            os.replace(self.path, self.destination)

    def copy_to(self, path):
        self.stream.flush()
        shutil.copyfile(self.path, path)

    def abort(self):
        self.stream.close()
        self.path.unlink(missing_ok=True)


def public_verdict(result, comparison=None, config=None):
    """Execution errors take precedence over any partial/unfinished output."""
    if result.status:
        if config is not None:
            memory = str(config.get("memory_mib", "inf"))
            timeout = str(config.get("timeout_ms", "inf"))
            if memory != "inf" and result.peak_bytes > int(memory) * MIB:
                return "MLE"
            if timeout != "inf" and result.elapsed_ns > int(timeout) * 1000000:
                return "TLE"
        return {"RTE": "RE", "OK": "RE"}.get(result.verdict, result.verdict)
    if comparison is not None:
        if comparison.incomplete:
            return "INCOMPLETE"
        return "AC" if comparison.equal else "WA"
    return "AC"


def case_protocol(report, config, number, incoming, actual, answer, result, comparison, seed=None):
    """Payloads first, then verdict and metrics; never color saved reports."""
    verdict = public_verdict(result, comparison, config)
    if config.get("_failed_output") and result.verdict == "WA":
        verdict = "WA"
    config["_resource_violations"] = []
    for name, field, used, scale in (
        ("MLE", "memory_mib", result.peak_bytes, MIB),
        ("TLE", "timeout_ms", result.elapsed_ns, 1000000),
    ):
        budget = str(config.get(field, "inf"))
        if budget != "inf" and used > int(budget) * scale:
            config["_resource_violations"].append(name)
    report.emit("\n" + "=" * 64)
    report.emit("TEST {}{}".format(number, " (seed {})".format(seed) if seed is not None else ""))
    if config.get("report_tests", "all") == "all" or verdict != "AC":
        comparison = comparison or Comparison(False, False, 0, set(), set(), [])
        _failure_details(report, incoming, actual, answer, comparison, report.display_lines,
                         Path(config.get("actual", "out.txt")).name)
    # A hidden failing repeat is evidence, never a replacement for the first stdout.
    failed = config.get("_failed_output")
    if failed and Path(failed).exists():
        report.emit("FAILED REPEAT {} (raw: {}):".format(config.get("_failed_repeat"), failed))
        _section(report, "repeat-output", failed, display_limit=report.display_lines)
    stderr_paths = config.get("_stderr_paths", [])
    for label, path in stderr_paths:
        if not Path(path).exists() or not Path(path).stat().st_size:
            continue
        report.emit("STDERR ({}):".format(label))
        # Full stderr is exempt from diff caps, but escaping still happens in
        # bounded chunks so one enormous row cannot exhaust checker memory.
        with open(path, "rb") as source:
            while True:
                chunk = source.readline(65536)
                if not chunk:
                    break
                report.emit("  " + _quoted(chunk.rstrip(b"\n")))
    report.emit(
        "Test {}: {}{}".format(
            number, verdict, " (status {})".format(result.status) if result.status else ""
        )
    )
    report.emit(
        "  TIME: {}    MEMORY: {}{}".format(
            format_usage(result.elapsed_ns, config.get("time_unit", "ms")),
            format_usage(result.peak_bytes, config.get("memory_unit", "KiB"), True),
            "    RUNS: {}".format(config.get("_series_runs", 1)),
        )
    )
    if verdict in ("TLE", "MLE"):
        report.emit(
            "  LIMITS: {} ms / {} MiB; kill factors {} / {}".format(
                config.get("timeout_ms", "inf"),
                config.get("memory_mib", "inf"),
                config.get("time_factor", "2"),
                config.get("memory_factor", "2"),
            )
        )
    return verdict


def final_protocol(report, groups, unfinished=False):
    """One deterministic headline, with every affected ID retained below it."""
    order = ("CE", "MLE", "TLE", "RE", "WA", "AC")
    verdict = (
        "INTERRUPTED"
        if groups.get("INTERRUPTED")
        else "INCOMPLETE"
        if unfinished
        else next((name for name in order if groups.get(name)), "AC")
    )
    report.emit("\n" + "=" * 64)
    report.emit("FINAL VERDICT: " + verdict)
    for name in (*order, "INCOMPLETE", "GENERATOR_ERROR", "ORACLE_ERROR", "INTERRUPTED"):
        if groups.get(name):
            report.emit("  {}: {}".format(name, ", ".join(map(str, groups[name]))))
    return verdict


def compilation_report(config):
    """Compiler stderr stays live; only its structured outcome reaches here."""
    plan = _load_plan(config)
    report = Protocol(config)
    try:
        report.emit("PREPARATION: CE ({})".format(config.get("failed_role", "main")))
        report.emit("NOT RUN: " + ", ".join(map(str, plan.selected)))
        final_protocol(report, {"CE": plan.selected or ["preparation"]})
        report.finish()
    except BaseException:
        report.abort()
        raise
    return int(config.get("build_status", 1))


def retain_failed_repeat(config, number):
    """Keep hidden-repeat bytes after the checking temporary directory closes."""
    source = config.get("_failed_output")
    if not source or not Path(source).exists():
        return
    for suffix in range(1000000):
        target = Path("test-repeat-failure" + ("-{}".format(suffix) if suffix else ""))
        try:
            target.mkdir()
            break
        except FileExistsError:
            continue
    else:
        raise CheckSetupError("cannot choose a free repeat-evidence directory")
    destination = target / "stdout.txt"
    shutil.copyfile(source, destination)
    for index, (label, path) in enumerate(config.get("_stderr_paths", [])):
        if Path(path).exists():
            shutil.copyfile(path, target / ("stderr-{}.txt".format(index)))
    config["_failed_output"] = str(destination)
    (target / "case.txt").write_text(
        "test {}; failed repeat {}\n".format(number, config.get("_failed_repeat"))
    )


# Source: checking.py
"""Shared case execution, continuation, and output publication."""

import errno


def _runner(config):
    return Runner(timeout_ms=str(config.get('timeout_ms', 'inf')),
                  memory_mib=str(config.get('memory_mib', 'inf')),
                  show_time=bool(config.get('show_time')), show_memory=bool(config.get('show_memory')) or config.get('operation') in ('test', 'stress'),
                  show_command=False, time_factor=config.get('time_factor', '2'),
                  memory_factor=config.get('memory_factor', '2'),
                  time_unit=config.get('time_unit', 'ms'), memory_unit=config.get('memory_unit', 'KiB'))


def _show_run(config, argv, incoming, outgoing):
    if config.get('show_command'):
        print('{} < {} > {}'.format(shlex.join([str(x) for x in argv]),
              shlex.quote(str(incoming)), shlex.quote(str(outgoing))), file=sys.stderr)


def _run_files(runner, config, argv, incoming, outgoing, label, stderr=None):
    _show_run(config, argv, incoming, outgoing)
    with open(incoming, 'rb') as stdin, open(outgoing, 'wb') as stdout:
        return runner.run([str(x) for x in argv], stdin=stdin, stdout=stdout,
                          label=label, stderr=stderr, report=False)


def _publish_actual(source, destination):
    target = Path(destination)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=target.parent, prefix='.cp-run-output-', delete=False) as output:
            temporary = Path(output.name)
            with open(source, 'rb') as incoming: shutil.copyfileobj(incoming, output)
        os.replace(temporary, target)
    finally:
        if temporary is not None: temporary.unlink(missing_ok=True)


def _aggregate(verdicts):
    for verdict, status in verdicts:
        if verdict == 'INTERRUPTED': return status or 130
    for verdict, status in verdicts:
        if verdict in ('GENERATOR_ERROR', 'ORACLE_ERROR'): return status or 1
    if any(verdict == 'INCOMPLETE' for verdict, _ in verdicts): return 4
    for name, code in (('CE', 1), ('MLE', 125), ('TLE', 124)):
        if any(verdict == name for verdict, _ in verdicts): return code
    for verdict, status in verdicts:
        if verdict == 'RE': return status or 1
    return 3 if any(verdict == 'WA' for verdict, _ in verdicts) else 0


def execute_test(config):
    """Every auto/mult case owns an independent process budget and series."""
    plan = _load_plan(config)
    if not config.get('executable'): raise CheckUsageError('test execution needs a launch target')
    if not config.get('auto') and not config.get('mult') and config.get('num_test'):
        count = positive_setting(config['num_test'], '--test-iters')
        if str(config.get('timeout_ms', 'inf')) != 'inf':
            config['timeout_ms'] = str(int(config['timeout_ms']) * count)
    runner = _runner(config)
    argv = [*config.get('main_argv', [config['executable']]), *config.get('runtime_args', [])]
    verdicts, groups = [], {}
    positions = {number: i for i, number in enumerate(plan.ids or range(1, len(plan.inputs) + 1))}
    with check_lock(), tempfile.TemporaryDirectory(prefix='.cp-run-test-', dir='.') as temporary:
        directory = Path(temporary)
        report, combined = Protocol(config), directory / 'combined.stdout'
        try:
            if plan.zero_notice: print('cp-run: tests use 1-based indices; using 1 instead of 0', file=sys.stderr)
            report.emit('cp-run test: selected {} of {} cases'.format(len(plan.selected), len(plan.inputs)))
            with open(combined, 'wb') as all_output:
                for position, number in enumerate(plan.selected):
                    incoming, answer, actual = (directory / name for name in ('in.txt', 'ans.txt', 'actual.txt'))
                    index = positions[number]
                    plan.inputs[index].copy_to(incoming); plan.answers[index].copy_to(answer)
                    actual.unlink(missing_ok=True)
                    result, comparison = run_candidate(runner, config, argv, incoming, actual, answer, 'test {}'.format(number))
                    if position and (config.get('auto') or config.get('mult')): all_output.write(plan.separator)
                    with open(actual, 'rb') as stream: shutil.copyfileobj(stream, all_output)
                    retain_failed_repeat(config, number)
                    verdict = case_protocol(report, config, number, incoming, actual, answer, result, comparison)
                    groups.setdefault(verdict, []).append(number)
                    for violation in config.get('_resource_violations', []):
                        if violation != verdict: groups.setdefault(violation, []).append(number)
                    verdicts.append((verdict, result.status))
                    if verdict == 'INTERRUPTED': break
            status = _aggregate(verdicts)
            final_protocol(report, groups, any(v in ('INCOMPLETE', 'INTERRUPTED') for v, _ in verdicts))
            summary = '{}: {} selected cases executed; {} failed'.format(
                'PASS' if not status else 'INCOMPLETE' if status == 4 else 'FAIL',
                len(verdicts), sum(v != 'AC' for v, _ in verdicts))
            report.emit(summary)
            if not config.get('cout'): print('cp-run: ' + summary + '; report: ' + str(config.get('report', 'test_out')), file=sys.stderr)
            # Keep same-filesystem publication cheap; a workspace output may
            # live on another mount, where replacement needs sibling staging.
            try:
                os.replace(combined, config['actual'])
            except OSError as error:
                if error.errno != errno.EXDEV: raise
                _publish_actual(combined, config['actual'])
            report.finish()
            return status
        except BaseException:
            report.abort(); raise


# Source: stress.py
"""Reproducible generator/reference/candidate checks and failure bundles."""

def _file_digest(path):
    """Failure payloads can be huge even when the bounded comparison stopped."""
    digest = hashlib.sha256()
    with open(path, 'rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''): digest.update(chunk)
    return digest.hexdigest()


def _bundle(config, report, directory, seed, iteration, verdict, results):
    """Keep exact bytes and argv; replay does not depend on generator determinism."""
    base = Path("stress-failure")
    for suffix in range(1000000):
        destination = base if suffix == 0 else Path(str(base) + "-" + str(suffix))
        try:
            destination.mkdir()
            break
        except FileExistsError:
            continue
    else:
        raise CheckSetupError("cannot choose a free stress failure directory")
    files = {}
    for filename in ("in.txt", "ans.txt", "out.txt"):
        source = directory / filename
        if source.exists():
            target = destination / filename
            shutil.copyfile(source, target)
            files[filename] = _file_digest(target)
    failed_repeat = config.get('_failed_output')
    if failed_repeat and Path(failed_repeat).exists():
        shutil.copyfile(failed_repeat, destination / 'failed-repeat.txt')
    for index, (_, path) in enumerate(config.get('_stderr_paths', [])):
        if Path(path).exists(): shutil.copyfile(path, destination / ('stderr-{}.txt'.format(index)))
    report.copy_to(destination / "test_out")
    destination = destination.resolve()
    if verdict in ("GENERATOR_ERROR", "ORACLE_ERROR") or "candidate" not in results:
        replay = [str(config.get("script", "cp-run")), "stress", "run", str(config["executable"]),
                  str(config["brute"]), str(config["generator"]), "--seed=" + str(seed), "--test-iters=1",
                  "--TLE=" + str(config.get("timeout_ms", "inf")),
                  "--MLE=" + str(config.get("memory_mib", "inf")), "--", *config.get("runtime_args", [])]
    else:
        replay = [str(config.get("script", "cp-run")), "test", "run", str(config["executable"]),
                  str(destination / "in.txt"), str(destination / "ans.txt"), str(destination / "replay-report.txt"),
                  "--TLE=" + str(config.get("timeout_ms", "inf")),
                  "--MLE=" + str(config.get("memory_mib", "inf")), "--", *config.get("runtime_args", [])]
    # A saved candidate failure replays against the saved answer, so only its
    # exact interpreter options are needed; no source/profile is regenerated.
    chosen = config.get('main_argv', [])
    if config.get('executable', '').endswith('.py') and chosen:
        boundary = replay.index('--')
        replay[boundary:boundary] = ['--interpreter=' + chosen[0], *['--interpreter-arg=' + arg for arg in chosen[1:-1]]]
    if config.get('show_time') or config.get('show_memory'):
        boundary = replay.index('--')
        replay[boundary:boundary] = [flag for enabled, flag in (
            (config.get('show_time'), '-t'), (config.get('show_memory'), '-m')) if enabled] + [
            '--average=' + str(config.get('average', 1)), '--warm-up=' + str(int(bool(config.get('warmup'))))]
    manifest = {"format": "cp-run-failure", "schema": 2, "cwd": str(Path.cwd()), "seed": seed, "iteration": iteration, "verdict": verdict,
                "commands": {"main": [*config.get("main_argv", [config["executable"]]), *config.get("runtime_args", [])],
                             "brute": config.get("brute_argv", [config["brute"]]), "generator": [*config.get("generator_argv", [config["generator"]]), str(seed)]},
                "limits": {"timeout_ms": config.get("timeout_ms", "inf"), "memory_mib": config.get("memory_mib", "inf")},
                "measurement": {key: config.get(key) for key in ('warmup', 'average', 'time_factor', 'memory_factor')},
                "results": results, "sha256": files, "replay_argv": replay,
                "tools": {role: config.get("tool_" + role) for role in ("main", "brute", "generator")}}
    manifest["executables"] = {}
    for role, key in (("main", "executable"), ("brute", "brute"), ("generator", "generator")):
        path = Path(config[key])
        identity = {"path": str(path.resolve())}
        try:
            identity["sha256"] = _file_digest(path)
        except OSError as error:
            # A program can remove/change its own executable. Keep the useful
            # counterexample even when optional binary identity is unavailable.
            identity["hash_error"] = str(error)
        manifest["executables"][role] = identity
    (destination / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("cp-run: saved failure: " + str(destination), file=sys.stderr)
    print("cp-run: replay: " + shlex.join(replay), file=sys.stderr)
    return destination


def execute_stress(config):
    """Continue independent seeds, preserving role failures and bounded evidence."""
    plan = _prepare_check(config)
    for key in ('executable', 'brute', 'generator'):
        if not config.get(key): raise CheckUsageError('stress needs ' + key)
    runner = _runner(config)
    count = positive_setting(config.get('num_test') or config.get('iterations', 1000), 'stress iterations')
    start = int(config.get('seed', 4))
    main_argv = [*config.get('main_argv', [config['executable']]), *config.get('runtime_args', [])]
    verdicts, groups, saved = [], {}, 0
    maximum = positive_setting(config.get('max_failures', 10), 'failure bundle limit')
    with check_lock(), tempfile.TemporaryDirectory(prefix='.cp-run-stress-', dir='.') as temporary:
        directory, report = Path(temporary), Protocol(config)
        incoming, answer, actual = (directory / name for name in ('in.txt', 'ans.txt', 'out.txt'))
        seed, iteration, results = start, 0, {}
        current_bundle = None
        try:
            report.emit('cp-run stress: start seed {}; maximum {} iterations'.format(start, count))
            for iteration in range(1, count + 1):
                seed = (start + iteration - 1) % 2**64
                results, verdict, comparison = {}, None, None
                current_bundle = None
                for target in (incoming, answer, actual): target.write_bytes(b'')
                role_stderr = []
                # A failing generator/oracle leaves this seed unresolved. Its
                # role error cannot be misreported as a candidate wrong answer.
                for role, argv, source, target in (
                    ('generator', [*config.get('generator_argv', [config['generator']]), str(seed)], os.devnull, incoming),
                    ('reference', config.get('brute_argv', [config['brute']]), incoming, answer)):
                    error_path = directory / (role + '.stderr')
                    with open(error_path, 'wb') as stderr:
                        result = _run_files(runner, config, argv, source, target, role, stderr)
                    role_stderr.append((role, str(error_path)))
                    results[role] = {'status': result.status, 'elapsed_ns': result.elapsed_ns, 'peak_bytes': result.peak_bytes}
                    if result.status:
                        verdict = 'INTERRUPTED' if result.verdict == 'INTERRUPTED' else ('GENERATOR_ERROR' if role == 'generator' else 'ORACLE_ERROR')
                        config['_stderr_paths'] = role_stderr
                        case_protocol(report, config, iteration, incoming, actual, answer, result, None, seed)
                        report.emit('ROLE FAILURE: ' + verdict)
                        break
                if verdict is None:
                    actual.unlink(missing_ok=True)
                    result, comparison = run_candidate(runner, config, main_argv, incoming, actual, answer, 'candidate {}'.format(iteration))
                    config['_stderr_paths'] = role_stderr + config.get('_stderr_paths', [])
                    results['candidate'] = {'status': result.status, 'elapsed_ns': result.elapsed_ns, 'peak_bytes': result.peak_bytes}
                    _publish_actual(actual, config['actual'])
                    verdict = case_protocol(report, config, iteration, incoming, actual, answer, result, comparison, seed)
                    report.emit('Iteration {}: {} (seed {})'.format(iteration, verdict, seed))
                verdicts.append((verdict, result.status))
                groups.setdefault(verdict, []).append(iteration)
                if verdict in ('TLE', 'MLE'):
                    for violation in config.get('_resource_violations', []):
                        if violation != verdict: groups.setdefault(violation, []).append(iteration)
                if verdict != 'AC' and saved < maximum:
                    bundle = _bundle(config, report, directory, seed, iteration, verdict, results)
                    current_bundle = bundle
                    saved += 1
                    if config.get('minimize') and verdict == 'WA':
                        minimize_failure(config, directory, bundle)
                if verdict == 'INTERRUPTED' or (verdict != 'AC' and config.get('stop_on_failure')): break
            status = _aggregate(verdicts)
            final_protocol(report, groups, any(v in ('INCOMPLETE', 'GENERATOR_ERROR', 'ORACLE_ERROR', 'INTERRUPTED') for v, _ in verdicts))
            summary = 'No difference in {} generated cases'.format(iteration) if not status else 'Stress checked {} cases; failures retained'.format(iteration)
            report.emit(summary)
            if not config.get('cout'): print('cp-run: ' + summary + '; report: ' + str(config.get('report', 'test_out')), file=sys.stderr)
            report.finish()
            return status
        except KeyboardInterrupt:
            report.emit('INTERRUPTED at iteration {} (seed {})'.format(iteration, seed))
            if incoming.exists() and current_bundle is None: _bundle(config, report, directory, seed, iteration, 'INTERRUPTED', results)
            report.finish(); return 130
        except BaseException:
            report.abort(); raise


# Source: minimization.py
"""Bounded, validity-aware delta reduction of reproducible wrong answers.

The declared grammar owns count repair. A validator may add problem-specific
constraints; an oracle's successful exit alone is not an input-validity proof.
"""


class ReductionBudget(Exception):
    pass


class ReductionInterrupted(KeyboardInterrupt):
    def __init__(self, best, attempts):
        self.best, self.attempts = best, attempts


class SequenceGrammar:
    """N followed by exactly N integer tokens; no inferred graph/tree grammar."""

    def decode(self, payload):
        words = payload.split()
        if not words or len(words[0]) > 12 or not words[0].isdigit():
            raise CheckUsageError("sequence needs an initial N")
        count = int(words[0])
        if count != len(words) - 1 or count > 100000:
            raise CheckUsageError("sequence needs exactly N values (at most 100000)")
        if any(not re.fullmatch(rb"-?[0-9]{1,64}", word) for word in words[1:]):
            raise CheckUsageError("sequence values must be integers of at most 64 digits")
        return [int(word) for word in words[1:]]

    def encode(self, items):
        return (str(len(items)) + "\n" + " ".join(map(str, items)) + "\n").encode("ascii")


class CaseLineGrammar:
    """T followed by T independent, single-line testcase records."""

    def decode(self, payload):
        rows = payload.splitlines(keepends=True)
        if not rows or not rows[0].strip().isdigit():
            raise CheckUsageError("cases need an initial T")
        if int(rows[0]) != len(rows) - 1 or len(rows) > 100001:
            raise CheckUsageError("cases need exactly T single-line records")
        return rows[1:]

    def encode(self, items):
        return str(len(items)).encode() + b"\n" + b"".join(items)


class LineGrammar:
    def decode(self, payload):
        rows = payload.splitlines(keepends=True)
        if len(rows) > 100000:
            raise CheckUsageError("reduction exceeds 100000 records")
        return rows

    def encode(self, items):
        return b"".join(items)


def reduce_items(payload, grammar, predicate, attempts=200, seconds=30):
    """Complement deletion, then integer simplification; no global-minimum claim."""
    deadline = time.monotonic() + seconds
    items = grammar.decode(payload)
    best, count, cache = payload, 0, {}

    def accepts(proposal):
        nonlocal count, best
        if count >= attempts or time.monotonic() >= deadline:
            raise ReductionBudget
        digest = hashlib.sha256(proposal).digest()
        if digest not in cache:
            count += 1
            cache[digest] = predicate(proposal, deadline)
        if cache[digest]:
            best = proposal
        return cache[digest]

    reason = "no smaller confirmed input"
    try:
        # Canonicalizing a grammar is itself a proposal, never assumed safe.
        initial = grammar.encode(items)
        if not accepts(initial):
            return payload, count, "failure was not reproducible under the declared grammar"
        granularity = 2
        while items:
            width = (len(items) + granularity - 1) // granularity
            changed = False
            for offset in range(0, len(items), width):
                candidate = items[:offset] + items[offset + width :]
                if accepts(grammar.encode(candidate)):
                    items = candidate
                    granularity = max(2, granularity - 1)
                    changed = True
                    break
            if changed:
                continue
            if granularity >= len(items):
                break
            granularity = min(len(items), granularity * 2)
        if isinstance(grammar, SequenceGrammar):
            for index in range(len(items)):
                old = items[index]
                for value in dict.fromkeys((0, 1 if old > 0 else -1, old // 2)):
                    if abs(value) >= abs(old):
                        continue
                    candidate = list(items)
                    candidate[index] = value
                    if accepts(grammar.encode(candidate)):
                        items = candidate
                        old = value
        reason = "completed available reduction steps"
    except ReductionBudget:
        reason = "reduction budget exhausted; best confirmed input retained"
    except KeyboardInterrupt:
        raise ReductionInterrupted(best, count) from None
    return best, count, reason


def minimize_failure(config, directory, bundle):
    """Save reduced files beside untouched original evidence, never over it."""
    original = Path(directory) / "in.txt"
    if original.stat().st_size > 4 * 1024 * 1024:
        print("cp-run: reduction skipped: input exceeds 4 MiB", file=sys.stderr)
        return
    mode = config.get("minimize", "sequence")
    validator = config.get("validator")
    if mode in ("lines", "cases") and not validator:
        raise CheckUsageError("lines/cases reduction requires --validator=PROGRAM")
    grammar = {"sequence": SequenceGrammar, "cases": CaseLineGrammar, "lines": LineGrammar}[mode]()
    main = [*config.get("main_argv", [config["executable"]]), *config.get("runtime_args", [])]
    oracle = config.get("brute_argv", [config["brute"]])
    payload = original.read_bytes()
    with tempfile.TemporaryDirectory(prefix=".cp-run-reduce-", dir=".") as temporary:
        root = Path(temporary)
        incoming, answer, actual, error = [
            root / name for name in ("input", "answer", "actual", "stderr")
        ]

        def predicate(proposal, deadline):
            incoming.write_bytes(proposal)
            # Two confirmations reject simple stateful/flaky failures. Every
            # launch is bounded by both its original allowance and job deadline.
            for _ in range(2):
                remaining = int((deadline - time.monotonic()) * 1000)
                if remaining < 1:
                    raise ReductionBudget
                native = str(config.get("timeout_ms", "inf"))
                budget = remaining if native == "inf" else min(remaining, int(native))
                runner = Runner(
                    timeout_ms=str(budget),
                    memory_mib=str(config.get("memory_mib", "inf")),
                    time_factor="1",
                    memory_factor="1",
                )
                if validator:
                    command = [str(validator)]
                    if str(validator).endswith(".py"):
                        command.insert(0, config.get("validator_interpreter", sys.executable))
                    with (
                        open(incoming, "rb") as stdin,
                        open(os.devnull, "wb") as sink,
                        open(error, "wb") as stderr,
                    ):
                        checked = runner.run(
                            command, stdin=stdin, stdout=sink, stderr=stderr, report=False
                        )
                        if checked.verdict == "INTERRUPTED":
                            raise KeyboardInterrupt
                        if checked.status:
                            return False
                for command, target in ((oracle, answer), (main, actual)):
                    remaining = int((deadline - time.monotonic()) * 1000)
                    if remaining < 1:
                        raise ReductionBudget
                    runner.timeout_ns = min(runner.timeout_ns, remaining * 1000000)
                    runner.kill_time_ns = runner.timeout_ns
                    with open(error, "wb") as stderr:
                        outcome = _run_files(
                            runner, {}, command, incoming, target, "reduction", stderr
                        )
                    if outcome.verdict == "INTERRUPTED":
                        raise KeyboardInterrupt
                    if outcome.status:
                        return False
                difference = compare_case(actual, answer, config)
                if difference.equal or difference.incomplete:
                    return False
            return True

        best, attempts = payload, 0
        try:
            best, attempts, reason = reduce_items(
                payload,
                grammar,
                predicate,
                positive_setting(config.get("minimize_attempts", 200), "reduction attempts"),
                positive_setting(config.get("minimize_seconds", 30), "reduction seconds"),
            )
            # Recheck using the original repetition/limits; changed verdicts
            # never publish an alleged reduction.
            incoming.write_bytes(best)
            with open(error, "wb") as stderr:
                reference = _run_files(
                    _runner(config), {}, oracle, incoming, answer, "reference", stderr
                )
            if reference.verdict == "INTERRUPTED":
                raise KeyboardInterrupt
            trial = dict(config, operation="test")
            result, comparison = run_candidate(
                _runner(trial), trial, main, incoming, actual, answer, "reduced"
            )
            if result.verdict == "INTERRUPTED":
                raise KeyboardInterrupt
            confirmed = (
                not reference.status
                and result.verdict == "WA"
                and comparison
                and not comparison.equal
                and not comparison.incomplete
            )
            if confirmed:
                shutil.copyfile(incoming, Path(bundle) / "reduced-input.txt")
                shutil.copyfile(answer, Path(bundle) / "reduced-ans.txt")
                shutil.copyfile(actual, Path(bundle) / "reduced-out.txt")
            note = {
                "strategy": mode,
                "attempts": attempts,
                "reason": reason,
                "confirmed": bool(confirmed),
                "original_bytes": len(payload),
                "reduced_bytes": len(best),
            }
            (Path(bundle) / "reduction.json").write_text(json.dumps(note, indent=2) + "\n")
            print(
                "cp-run: reduction: {} -> {} bytes; {}{}".format(
                    len(payload),
                    len(best),
                    reason,
                    "" if confirmed else "; not confirmed, original retained",
                ),
                file=sys.stderr,
            )
        except KeyboardInterrupt as stop:
            partial = stop.best if isinstance(stop, ReductionInterrupted) else best
            (Path(bundle) / "partial-reduced-input.txt").write_bytes(partial)
            (Path(bundle) / "reduction.json").write_text(
                json.dumps(
                    {
                        "confirmed": False,
                        "interrupted": True,
                        "original_bytes": len(payload),
                        "partial_bytes": len(partial),
                    }
                )
                + "\n"
            )
            raise
        except (CheckUsageError, CheckSetupError, ReductionBudget) as error:
            print("cp-run: reduction skipped: " + str(error), file=sys.stderr)


# Source: companion.py
"""Optional foreground Competitive Companion receiver; no external server."""


def companion_samples(payload):
    """Validate protocol data without trusting remote names, paths or limits."""

    def unique(pairs):
        record = {}
        for key, value in pairs:
            if key in record:
                raise CheckUsageError("duplicate Companion JSON key: " + key)
            record[key] = value
        return record

    try:
        data = json.loads(payload, object_pairs_hook=unique)
    except (ValueError, UnicodeError, RecursionError) as error:
        raise CheckUsageError("invalid Companion JSON: " + str(error)) from None
    if not isinstance(data, dict):
        raise CheckUsageError("Companion request must be an object")
    batch = data.get("batch", {})
    if (
        not isinstance(batch, dict)
        or type(batch.get("size", 1)) is not int
        or batch.get("size", 1) != 1
    ):
        raise CheckUsageError("this listener accepts one problem; import a single problem page")
    tests = data.get("tests")
    if not isinstance(tests, list) or not 1 <= len(tests) <= 100000:
        raise CheckUsageError("Companion request needs 1..100000 samples")
    result = []
    for number, test in enumerate(tests, 1):
        if not isinstance(test, dict) or not all(
            isinstance(test.get(k), str) for k in ("input", "output")
        ):
            raise CheckUsageError("sample {} needs string input/output".format(number))
        try:
            result.append((test["input"].encode("utf-8"), test["output"].encode("utf-8")))
        except UnicodeError:
            raise CheckUsageError("sample contains invalid Unicode") from None
    return result


def import_companion(config, payload):
    samples = companion_samples(payload)
    root = layout_root(config)
    entries = [(test_filename(stream, number), content)
               for number, sample in enumerate(samples, 1)
               for stream, content in zip(("in", "ans"), sample)]
    # A shorter import must not silently leave tests from another problem.
    if root.is_dir():
        for stream in ("in", "ans"):
            if set(discover_cases(root, stream)) - set(range(1, len(samples) + 1)):
                raise CheckUsageError("existing extra samples would remain; choose a clean test folder")
    write_test_files(root, entries, bool(config.get("overwrite")), config.get("protected", []))
    return len(samples), root


def companion_server(address, handler):
    """Bind numeric loopback without HTTPServer's slow reverse-DNS lookup."""
    from http.server import HTTPServer
    from socketserver import TCPServer

    class LocalServer(HTTPServer):
        def server_bind(self):
            TCPServer.server_bind(self)
            self.server_name = "localhost"
            self.server_port = self.server_address[1]

    return LocalServer(address, handler)


def execute_companion(config):
    # HTTP imports are optional; ordinary measurements never pay their startup cost.
    from http.server import BaseHTTPRequestHandler

    port = positive_setting(config.get("port", 27122), "--port")
    if port > 65535:
        raise CheckUsageError("--port must be 1..65535")
    wait = positive_setting(config.get("wait", 120), "--wait")
    maximum = min(
        4 * 1024 * 1024, positive_setting(config.get("max_spool", 268435456), "request limit")
    )
    accepted = []

    class Handler(BaseHTTPRequestHandler):
        timeout = 3  # Includes reading headers, before do_POST is entered.

        def log_message(self, *args):
            pass

        def do_POST(self):
            try:
                self.connection.settimeout(3)
                if self.path != "/":
                    raise CheckUsageError("Companion endpoint is POST /")
                origin = self.headers.get("Origin", "")
                if origin and not origin.startswith(("chrome-extension://", "moz-extension://")):
                    raise CheckUsageError("browser page origins are not accepted")
                if self.headers.get_content_type() != "application/json":
                    raise CheckUsageError("Content-Type must be application/json")
                length = self.headers.get("Content-Length", "")
                if (
                    not length.isascii()
                    or not length.isdecimal()
                    or len(length) > 10
                    or not 0 < int(length) <= maximum
                ):
                    raise CheckUsageError("invalid or oversized Content-Length")
                payload = self.rfile.read(int(length))
                if len(payload) != int(length):
                    raise CheckUsageError("truncated Companion request")
                count, root = import_companion(config, payload)
                accepted.append(count)
                message = "Saved {} samples in {}".format(count, root)
                self.send_response(200)
                print("cp-run: " + message, file=sys.stderr, flush=True)
            except (ValueError, OSError) as error:
                message = str(error)
                self.send_response(400)
                print("cp-run: Companion: " + message, file=sys.stderr, flush=True)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            body = (message + "\n").encode("utf-8")
            self.send_header("Content-Length", str(len(body)))
            try:
                self.end_headers()
                self.wfile.write(body)
            except (BrokenPipeError, ConnectionResetError):
                pass  # Receipt already committed.

    deadline = time.monotonic() + wait
    with companion_server(("127.0.0.1", port), Handler) as server:
        print(
            "cp-run: Companion listening on http://localhost:{}/; import one problem".format(
                server.server_port
            ),
            file=sys.stderr,
            flush=True,
        )
        while not accepted and time.monotonic() < deadline:
            server.timeout = min(0.25, max(0, deadline - time.monotonic()))
            server.handle_request()
    if not accepted:
        raise CheckSetupError("Companion wait expired without a successful import")
    return 0


# Source: format_review.py
"""Structured findings, temporary annotations and two-phase interactive review."""
from dataclasses import dataclass, field
import difflib
import hashlib


def format_source_list(config):
    return config.get('format_sources', config.get('protected', []))


class FormatFinding(str):
    """Render findings without making callers parse text to discover severity."""
    def __new__(cls, source, line, column, rule, severity, message):
        value = str.__new__(cls, '{}:{}:{}: school {} {}: {}'.format(
            source, line, column, rule, severity, message))
        value.source, value.line, value.column = str(source), int(line), int(column)
        value.rule, value.severity, value.message = rule, severity, message
        return value

    def record(self):
        return dict(file=self.source, line=self.line, column=self.column, rule=self.rule,
                    severity=self.severity, message=self.message)


@dataclass
class FormatResult:
    findings: list = field(default_factory=list)
    jobs: list = field(default_factory=list)
    identities: dict = field(default_factory=dict)
    cache_jobs: list = field(default_factory=list)
    inputs: list = field(default_factory=list)

    @property
    def errors(self):
        return [item for item in self.findings if item.severity == 'error']

    @property
    def warnings(self):
        return [item for item in self.findings if item.severity != 'error']


FORMAT_MARKER = re.compile(
    r'/\*\s*(school-(?:error-justified|justified|error-comment|warning-comment|error|warning))'
    r'\s+([0-9.]+)(?:\s*:\s*(.*?))?\s*\*/', re.S)


def format_annotations(text):
    """Only real comments create annotations; consecutive markers share a target."""
    tokens = list(SCHOOL_LEXER.finditer(text))
    for token in tokens:
        if not token.group('comment'):
            continue
        marker = FORMAT_MARKER.fullmatch(token[0])
        if not marker:
            continue
        end = token.end()
        while True:
            while end < len(text) and text[end].isspace():
                end += 1
            following = next((item for item in tokens if item.start() == end), None)
            if following and FORMAT_MARKER.fullmatch(following[0]):
                end = following.end()
            else:
                break
        yield token, marker, text[:end].count('\n') + 1


def format_strip_automatic(text):
    """Remove only managed temporary notes, including leftovers after SIGKILL."""
    edits = []
    for token, marker, _ in format_annotations(text):
        if marker[1] not in ('school-error', 'school-warning'):
            continue
        start, end = token.span()
        left = text.rfind('\n', 0, start) + 1
        right = text.find('\n', end)
        right = len(text) if right < 0 else right + 1
        if not text[left:start].strip() and not text[end:right].strip():
            edits.append((left, right))
        else:
            if text[end:end + 1] == ' ':
                end += 1
            edits.append((start, end))
    for start, end in sorted(set(edits), reverse=True):
        text = text[:start] + text[end:]
    return text


def format_report_target(value, protected, overwrite=False):
    target = Path(value).expanduser().absolute()
    for name in protected:
        source = Path(name)
        if target.resolve() == source.resolve() or target.exists() and source.exists() and os.path.samefile(target, source):
            raise CheckUsageError('report collides with a protected file: ' + str(target))
    if target.is_symlink() or target.exists() and not target.is_file():
        raise CheckUsageError('report must be a regular file: ' + str(target))
    if target.exists() and not overwrite:
        raise CheckUsageError('report exists; use --overwrite: ' + str(target))
    if not target.parent.is_dir():
        raise CheckUsageError('report directory not found: ' + str(target.parent))
    return target


class FormatReport:
    """Write initial snapshots before decisions and update the final audit trail."""
    def __init__(self, config):
        self.protected = config.get('protected', [])
        self.overwrite = config.get('overwrite', False)
        value = config.get('review_report')
        self.target = format_report_target(value, self.protected, self.overwrite) if value else None
        self.owned = {}
        self.initial, self.records = [], []
        self.build_interrupted = False
        self.state, self.phase = 'pending', ''

    def write(self, target=None):
        target = target or self.target
        if target is None:
            return
        if target in self.owned and target.read_bytes() != self.owned[target]:
            raise CheckSetupError('report changed during review: ' + str(target))
        data = (json.dumps(dict(schema=1, state=self.state, phase=self.phase, build_interrupted=self.build_interrupted,
                               initial=self.initial, findings=self.records),
                           ensure_ascii=False, indent=2) + '\n').encode('utf-8')
        descriptor, temporary = tempfile.mkstemp(prefix='.cp-review-', dir=target.parent)
        try:
            with os.fdopen(descriptor, 'wb') as stream:
                stream.write(data)
            if target in self.owned or self.overwrite:
                os.replace(temporary, target)
            else:
                os.link(temporary, target)  # Exclusive creation closes a preflight race.
            self.owned[target] = data
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)


def format_comment(source, finding, text='', kind='comment'):
    """Place metadata before the affected physical line without touching tokens."""
    if any(ord(char) < 32 for char in text) or '*/' in text:
        raise CheckUsageError('comment contains a control character or */')
    original = source.read_bytes()
    decoded = original.decode('utf-8')
    lines = decoded.splitlines(keepends=True)
    if not 1 <= finding.line <= len(lines):
        raise CheckSetupError('annotation location changed: ' + str(source))
    position = sum(len(line) for line in lines[:finding.line - 1])
    for token in SCHOOL_LEXER.finditer(decoded):
        if token.start() < position < token.end():
            raise CheckSetupError('cannot annotate inside a multiline literal/comment: ' + str(source))
    if any(left < position < right for left, right in school_directive_spans(decoded)):
        raise CheckSetupError('cannot annotate inside a continued directive: ' + str(source))
    if kind == 'justified':
        marker = 'school-error-justified' if finding.severity == 'error' else 'school-justified'
    else:
        marker = 'school-' + ('error' if finding.severity == 'error' else 'warning')
        if kind == 'comment':
            marker += '-comment'
    line = lines[finding.line - 1]
    indent = line[:len(line) - len(line.lstrip(' '))]
    note = indent + '/* {} {}{} */\n'.format(marker, finding.rule, ': ' + text.strip() if text.strip() else '')
    candidate = decoded[:position] + note + decoded[position:]
    if [value for value, _ in school_tokens(decoded)] != [value for value, _ in school_tokens(candidate)]:
        raise CheckSetupError('annotation would change source tokens')
    school_publish([(source, original, candidate.encode('utf-8'))])


def format_cleanup(paths):
    jobs = []
    for value in dict.fromkeys(paths):
        source = Path(value)
        if source.is_file():
            original = source.read_bytes()
            try:
                candidate = format_strip_automatic(original.decode('utf-8')).encode('utf-8')
            except UnicodeDecodeError:
                continue
            jobs.append((source, original, candidate))
    school_publish(jobs)


def format_map_line(before, after, line):
    old, new = before.splitlines(), after.splitlines()
    for tag, start, end, other, finish in difflib.SequenceMatcher(None, old, new, autojunk=False).get_opcodes():
        if start <= line - 1 < end:
            return other + (line - 1 - start if tag == 'equal' else 0) + 1
    return max(1, min(line, len(new)))


def format_snapshot(config):
    return {str(Path(value).resolve()): Path(value).read_bytes().decode('utf-8', errors='replace')
            for value in [*format_source_list(config), *config.get('review_related', [])] if Path(value).is_file()}


def format_collect(config):
    """Analyze all roles, then publish safe layout; check mode remains read-only."""
    result = school_analyze(config) if config.get('format_mode') == 'school' else format_clang_analyze(config)
    if config.get('review_report'):
        format_report_target(config['review_report'], [*config.get('protected', []), *result.inputs], True)
    check = config.get('prettier') == 'check'
    if check:
        for source, before, after in result.jobs:
            if format_strip_automatic(before.decode('utf-8')) != format_strip_automatic(after.decode('utf-8')):
                result.findings.append(FormatFinding(source, 1, 1, 'layout', 'error', 'formatting differs'))
    else:
        school_publish(result.jobs, result.identities)
    for source, candidate, findings, dependencies, tools in result.cache_jobs:
        format_cache_store(source, candidate, findings, dependencies, tools, config)
    return result


def execute_format_review(config, report=None):
    """Resolve errors first; only then expose and process review warnings."""
    if config.get('review') and config.get('prettier') == 'check':
        raise CheckUsageError('--review conflicts with --check')
    if config.get('review') and not (sys.stdin.isatty() and sys.stderr.isatty()):
        raise CheckUsageError('--review needs a terminal')
    report = report or FormatReport(config)
    result, snapshots = None, format_snapshot(config)
    active, seen_phases = [], set()

    def refresh():
        nonlocal result, snapshots, active
        before = snapshots
        try:
            result = format_collect(config)
        except (CheckSetupError, OSError) as error:
            if not config.get('review') and not report.target:
                raise
            source = config.get('protected', ['format'])[0]
            result = FormatResult([FormatFinding(source, 1, 1, 'backend', 'error', str(error))])
        config.setdefault('review_related', set()).update(item.source for item in result.findings if Path(item.source).is_file())
        report.protected = [*config.get('protected', []), *result.inputs]
        snapshots = format_snapshot(config)
        for record in report.records:
            source = record['file']
            if source in before and source in snapshots:
                record['line'] = format_map_line(before[source], snapshots[source], record['line'])
        phase = 'errors' if result.errors else 'review'
        visible = result.errors if result.errors else result.warnings
        active = []
        reused = set()
        for finding in visible:
            candidates = [entry for entry in report.records if
                (entry['file'], entry['rule'], entry['severity'], entry['message']) ==
                (finding.source, finding.rule, finding.severity, finding.message)
                and entry['decision'] not in ('fixed', 'justified') and entry['id'] not in reused]
            record = min(candidates, key=lambda entry: abs(entry['line'] - finding.line)) if candidates else None
            if record is not None:
                record.update(line=finding.line, column=finding.column)
                reused.add(record['id'])
            if record is None:
                record = finding.record()
                record.update(id=len(report.records) + 1, decision='pending', reviewer_comment='', comments=[])
                report.records.append(record)
                reused.add(record["id"])
            active.append((finding, record))
        if result.jobs:  # A backend failure cannot prove that previous findings were fixed.
            current = {(item.source, item.line, item.rule, item.severity, item.message) for item in result.findings}
            for record in report.records:
                identity = tuple(record[key] for key in ('file', 'line', 'rule', 'severity', 'message'))
                if identity not in current and record['decision'] == 'pending':
                    record['decision'] = 'fixed'
        report.phase = phase
        if phase not in seen_phases:
            report.initial.append(dict(phase=phase, findings=[item.record() for item in visible]))
            seen_phases.add(phase)
        for finding in visible:
            print(finding, file=sys.stderr)
        report.state = 'errors' if result.errors else 'review'
        report.write()

    def annotate(pairs, kind, text=''):
        # Removing temporary notes first keeps offsets unambiguous and makes cleanup idempotent.
        old = format_snapshot(config)
        format_cleanup([*format_source_list(config), *config.get('review_related', [])])
        clean = format_snapshot(config)
        for finding, record in sorted(pairs, key=lambda pair: (pair[0].source, pair[0].line), reverse=True):
            if finding.rule not in SCHOOL_RULES:
                print('this diagnostic cannot be annotated', file=sys.stderr)
                continue
            line = format_map_line(old[finding.source], clean[finding.source], finding.line)
            location = FormatFinding(finding.source, line, 1, finding.rule, finding.severity, finding.message)
            format_comment(Path(finding.source), location, finding.message if kind == 'auto' else text, kind)

    try:
        refresh()
        if not config.get('review'):
            report.state = 'errors' if result.errors else 'complete'
            return int(bool(result.errors))
        while True:
            pending = [(item, record) for item, record in active if record['decision'] == 'pending']
            if not pending:
                report.state = 'complete'
                return int(bool(result.errors))
            if config.get('annotate'):
                annotate(pending, 'auto')
                snapshots = format_snapshot(config)
            finding, record = pending[0]
            print('{}> '.format('error' if result.errors else 'review'), end='', file=sys.stderr, flush=True)
            entered = sys.stdin.readline()
            if not entered:
                report.state = 'incomplete'
                return 1
            try:
                parts = shlex.split(entered)
            except ValueError:
                print('invalid quoting', file=sys.stderr)
                continue
            if not parts:
                continue
            command = {'a': 'accept', 'd': 'deny', 'j': 'justified', 'c': 'comment', 'q': 'quit'}.get(parts[0], parts[0])
            if command == 'quit':
                report.state = 'incomplete'
                return 1
            if command == 'export':
                if len(parts) != 2:
                    print('expected a file', file=sys.stderr)
                    continue
                try:
                    requested = Path(parts[1]).expanduser().absolute()
                    target = requested if requested in report.owned else format_report_target(
                        parts[1], report.protected, config.get('overwrite', False))
                    report.write(target)
                except (CheckUsageError, CheckSetupError, OSError) as error:
                    print(str(error), file=sys.stderr)
                continue
            all_remaining = command in ('accept-all', 'deny-all', 'justified-all')
            if all_remaining:
                command = command.removesuffix('-all')
            elif len(parts) > 1 and parts[1] == 'all':
                all_remaining = True
                parts.pop(1)
            if command not in ('accept', 'deny', 'justified', 'comment'):
                print('invalid decision', file=sys.stderr)
                continue
            local_annotate = bool({'--annotate', '--anotate'} & set(parts[1:]))
            text = ' '.join(part for part in parts[1:] if part not in ('--annotate', '--anotate'))
            if any(ord(char) < 32 for char in text) or '*/' in text:
                print('invalid comment', file=sys.stderr)
                continue
            selected = pending if all_remaining else [(finding, record)]
            if command == 'deny' and result.errors:
                report.state = 'stopped'
                return 1
            if command == 'deny':
                for _, entry in selected:
                    entry.update(decision='deny', reviewer_comment=text)
                report.write()
                continue
            if command in ('comment', 'justified') or local_annotate:
                eligible = [(item, entry) for item, entry in selected if item.rule in SCHOOL_RULES]
                if len(eligible) != len(selected):
                    print('parser/compiler diagnostics cannot be justified or annotated; fix the code or toolchain, then accept.',
                          file=sys.stderr)
                if not eligible and command != 'accept':
                    continue
                if command in ('comment', 'justified'):
                    selected = eligible
            if command == 'comment':
                for _, entry in selected:
                    entry['comments'].append(text)
                annotate(selected, 'comment', text)
            elif command == 'justified':
                eligible = [(item, entry) for item, entry in selected if item.rule in SCHOOL_RULES]
                for _, entry in eligible:
                    entry.update(decision='justified', reviewer_comment=text)
                annotate(eligible, 'justified', text)
            elif local_annotate:
                annotate(selected, 'auto')
            if command == 'accept':
                for _, entry in selected:
                    entry['reviewer_comment'] = text
            refresh()
    except KeyboardInterrupt:
        report.state = 'interrupted'
        return 130
    finally:
        if config.get('review'):
            format_cleanup([*format_source_list(config), *config.get('review_related', [])])
        report.write()


def execute_strict_format(config):
    read_only = dict(config, prettier='check', review=False, annotate=False)
    report = FormatReport(config)
    result = format_collect(read_only)
    report.build_interrupted = bool(result.errors)
    if result.errors and sys.stdin.isatty() and sys.stderr.isatty():
        execute_format_review(dict(config, prettier='format', review=True), report)
        # The original build is always interrupted, even after a clean review.
        return 1
    visible = result.errors if result.errors else result.warnings
    report.phase = 'errors' if result.errors else 'check'
    report.state = 'errors' if result.errors else 'complete'
    report.initial = [dict(phase=report.phase, findings=[item.record() for item in visible])]
    report.records = [dict(item.record(), decision='pending' if result.errors else 'not-reviewed',
                           reviewer_comment='', comments=[]) for item in visible]
    for item in result.errors:
        print(item, file=sys.stderr)
    report.write()
    return int(bool(result.errors))


def format_clang_analyze(config):
    """Use stdin to stage project-style formatting without editing any role."""
    tools, jobs = [], []
    for value in dict.fromkeys(format_source_list(config)):
        source = Path(value).resolve()
        python = source.suffix == '.py'
        tool = config.get('python_formatter', 'ruff') if python else config.get('native_formatter', 'clang-format')
        executable = shutil.which(tool)
        if not executable:
            raise CheckSetupError('formatter not found: ' + tool)
        if python:
            argv = [executable, *([] if Path(tool).name.startswith('black') else ['format']),
                    '--stdin-filename=' + str(source), '-']
        else:
            argv = [executable, '--style=file', '--fallback-style=LLVM', '--sort-includes=false',
                    '--assume-filename=' + str(source)]
        tools.append((source, argv))
    findings, identities = [], {}
    for source, argv in tools:
        original = source.read_bytes()
        metadata = source.stat()
        identities[source] = metadata.st_dev, metadata.st_ino
        result = school_tool(argv, input=original, capture_output=True)
        if result.returncode:
            findings.append(FormatFinding(source, 1, 1, 'formatter', 'error',
                            result.stderr.decode('utf-8', errors='replace')))
        else:
            jobs.append((source, original, result.stdout))
    return FormatResult(findings, jobs, identities)


# Source: format_cache.py
"""Bounded result cache; unchanged source, tools and dependencies are mandatory."""
SCHOOL_ENGINE_ID = 'fdf1d24bc2e05e3f11afa3728dce900c23921554569648a8f72b3ace7a0a4a58'


def format_file_identity(value):
    path = Path(value)
    try:
        info = path.stat()
    except FileNotFoundError:
        return None
    return [str(path.resolve()), info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns]


def format_dependency_paths(text):
    """Decode compiler-generated Make prerequisites without shell expansion."""
    body = text.replace('\\\n', '')
    _, separator, prerequisites = body.partition(':')
    if not separator:
        raise ValueError('invalid compiler dependency record')
    return [value.replace('$$', '$') for value in shlex.split(prerequisites, comments=False) if value != '-']


def format_cache_location(source, config):
    if not config.get('format_cache', True):
        return None
    root = os.environ.get('XDG_CACHE_HOME')
    if not root:
        state = os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))
        root = str(Path(state) / 'cp-run')
    root = Path(root) / 'format-cache'
    try:
        root.mkdir(parents=True, exist_ok=True, mode=0o700)
        metadata = root.stat()
        if root.is_symlink() or metadata.st_uid != os.getuid() or metadata.st_mode & 0o022:
            return None
    except OSError:
        return None  # A cache is optional; all checks still run with a read-only home.
    digest = hashlib.sha256(str(source).encode()).hexdigest()
    return root / ('school-' + digest + '.json')


def format_cache_key(text, tools):
    record = dict(engine=SCHOOL_ENGINE_ID, cwd=str(Path.cwd()),
                  environment={key: os.environ.get(key) for key in ('CPATH', 'C_INCLUDE_PATH', 'CPLUS_INCLUDE_PATH', 'SDKROOT', 'DEVELOPER_DIR', 'GCC_EXEC_PREFIX', 'COMPILER_PATH', 'LIBRARY_PATH', 'SOURCE_DATE_EPOCH', 'LANG', 'LC_ALL', 'TZ')}, source=hashlib.sha256(text.encode('utf-8')).hexdigest(),
                  tools=[format_file_identity(value) for value in tools])
    return hashlib.sha256(json.dumps(record, sort_keys=True).encode()).hexdigest()


def format_cache_load(source, text, tools, config):
    path = format_cache_location(source, config)
    if path is None or any(value in text for value in ('__DATE__', '__TIME__', '__TIMESTAMP__')):
        return None
    try:
        if path.is_symlink() or path.stat().st_size > 4 * 1024 * 1024:
            return None
        record = json.loads(path.read_text())
        if not isinstance(record, dict) or not isinstance(record.get('dependencies'), dict) or not isinstance(record.get('findings'), list):
            return None
        if record['key'] != format_cache_key(text, tools) or record['candidate'] != text:
            return None
        if any(format_file_identity(value) != identity for value, identity in record['dependencies'].items()):
            return None
        allowed = set(SCHOOL_RULES) | {'review-comment', 'frontend', 'GCC'}
        findings = []
        for item in record['findings']:
            if not isinstance(item, dict):
                return None
            if (item['rule'] not in allowed or item['severity'] not in ('error', 'warning') or
                    item['file'] != str(source) and not Path(item['file']).is_absolute() or
                    type(item['line']) is not int or type(item['column']) is not int or
                    not isinstance(item['message'], str)):
                return None
            findings.append(FormatFinding(item['file'], item['line'], item['column'], item['rule'],
                                          item['severity'], item['message']))
        return findings, list(record['dependencies'])
    except (OSError, ValueError, KeyError, TypeError):
        return None



def format_include_candidates(source, text, dependencies, search_directories=(), owners=None):
    """Conservatively watch lookup alternatives without caching compiler output."""
    candidates, macro_owners, names, directories = set(), set(), set(), set()
    selected = None if owners is None else {Path(value) for value in owners}
    roots = list(dict.fromkeys([*search_directories, (str(source.parent), False)]))
    roots = [(Path(value), framework) for value, framework in roots]
    canonical_roots = [(root.parts, framework, root.resolve().parts) for root, framework in roots]
    project_parts = source.parent.resolve().parts
    local, searched = {}, set()

    def in_project(directory):
        key = str(directory)
        if key not in local:
            parts = directory.resolve().parts
            local[key] = parts[:len(project_parts)] == project_parts
        return local[key]

    gap = r'(?:[ \t\v\f]|/\*.*?\*/)*'
    literal = re.compile(r'#' + gap + r'include(?:_next)?\b' + gap + r'([<"])([^>"\r\n\0]+)[>"]', re.S)
    macro = re.compile(r'#' + gap + r'include(?:_next)?\b' + gap + r'[A-Za-z_]', re.S)
    presence = re.compile(r'__has_(?:include(?:_next)?|embed)\s*\(\s*([<"])([^>"\r\n\0]+)[>"]', re.S)
    opaque_presence = re.compile(r'__has_(?:include(?:_next)?|embed)\s*\(\s*[A-Za-z_]', re.S)

    def watch(candidate, directory=False):
        if directory and not in_project(candidate.parent):
            directories.add(candidate.parent)
        else:
            candidates.add(str(candidate.absolute()))

    def search_candidates(name, owner, directory=False):
        watch(owner / name, directory)
        key = name, directory
        if key in searched:
            return
        searched.add(key)
        for root, framework in roots:
            if framework:
                library, separator, remainder = name.partition('/')
                if separator:
                    for folder in ('Headers', 'PrivateHeaders'):
                        watch(root / (library + '.framework') / folder / remainder, directory)
            else:
                watch(root / name, directory)

    uncovered = False
    for owner in [source, *(Path(value) for value in dependencies)]:
        if owner != source and selected is not None and owner not in selected:
            if not owner.is_file():
                continue
        else:
            try:
                contents = text if owner == source else owner.read_text()
            except (OSError, UnicodeDecodeError):
                continue
            contents = contents.replace('\\\r\n', '').replace('\\\n', '')
            for directive in literal.finditer(contents):
                search_candidates(directive[2], owner.parent, directory=True)
            for expression in presence.finditer(contents):
                search_candidates(expression[2], owner.parent, directory=True)
            unknown = list(opaque_presence.finditer(contents))
            if unknown:
                ignored = [(token.start(), token.end()) for token in SCHOOL_LEXER.finditer(contents)]
                for expression in unknown:
                    before = contents[contents.rfind('\n', 0, expression.start()) + 1:expression.start()]
                    signature = re.fullmatch(r'\s*#\s*define\s+', before)
                    if not signature and not any(start <= expression.start() < end for start, end in ignored):
                        raise ValueError('nonliteral file-presence expression requires fresh preprocessing')
            if macro.search(contents):
                macro_owners.add(owner.parent)
        if owner != source:
            names.add(owner.name)
            covered = False
            parts, resolved = owner.parts, owner.resolve().parts
            for root, framework, canonical in canonical_roots:
                if parts[:len(root)] == root:
                    covered = True
                    relative = Path(*parts[len(root):])
                elif resolved[:len(canonical)] == canonical:
                    covered = True
                    relative = Path(*resolved[len(canonical):])
                else:
                    continue
                if not framework:
                    names.add(str(relative))
                elif relative.parts[0].endswith('.framework'):
                    for folder in ('Headers', 'PrivateHeaders'):
                        if folder in relative.parts:
                            position = relative.parts.index(folder)
                            names.add(relative.parts[0][:-len('.framework')] + '/' +
                                      '/'.join(relative.parts[position + 1:]))
            configuration = str(owner) in SCHOOL_CONFIGURATION_INPUTS or str(owner.resolve()) in SCHOOL_CONFIGURATION_INPUTS
            uncovered = uncovered or not (covered or configuration)
    if macro_owners and uncovered:
        raise ValueError('macro include has prerequisites outside the known search roots')
    # Macro spellings cannot always be reconstructed. Watch external lookup
    # directories; keep exact paths in the project so atomic editor saves do
    # not discard reusable preparation.
    for owner in macro_owners:
        for name in names:
            search_candidates(name, owner, directory=True)
    for directory in directories:
        candidates.add(str(directory.absolute()))
        try:
            with os.scandir(directory) as entries:
                for entry in entries:
                    # A dangling file link can become usable when its target
                    # appears without any change to this directory's entries.
                    if entry.is_symlink():
                        candidates.add(str(Path(entry.path).absolute()))
        except (FileNotFoundError, NotADirectoryError):
            continue
    return candidates


def format_volatile_inputs(text, dependencies):
    """Clock-dependent preprocessing must never become a reusable result."""
    names = ('__DATE__', '__TIME__', '__TIMESTAMP__')
    if any(name in text for name in names):
        return True
    for value in dependencies:
        try:
            if Path(value).is_dir():
                continue
            contents = Path(value).read_bytes()
        except FileNotFoundError:
            continue
        except (OSError, ValueError):
            return True
        if any(name.encode() in contents for name in names):
            return True
    return False


def format_cache_store(source, candidate, findings, dependencies, tools, config):
    path = format_cache_location(source, config)
    if (path is None or len(candidate.encode('utf-8')) > 2 * 1024 * 1024
            or format_volatile_inputs(candidate, dependencies)):
        return
    # Production callers pass the snapshot captured by the analysis, not a
    # fresh identity that could accidentally bless a concurrent header edit.
    try:
        if isinstance(dependencies, dict):
            snapshot = dict(dependencies)
        else:
            dependencies = set(dependencies) | {str(source.with_suffix('.h')),
                            str(source.parent / 'Makefile'), str(source.parent / 'makefile')}
            headers = [value for value in dependencies if Path(value).suffix in ('.h', '.hpp', '.hh', '.hxx')]
            dependencies.update(format_include_candidates(source, candidate, headers))
            snapshot = {value: format_file_identity(value) for value in dependencies}
        if any(format_file_identity(value) != identity for value, identity in snapshot.items()):
            return
        record = dict(key=format_cache_key(candidate, tools), candidate=candidate,
                      dependencies=snapshot, findings=[item.record() for item in findings])
    except (OSError, ValueError):
        return  # An unusable conservative candidate disables optional caching.
    temporary = None
    try:
        descriptor, temporary = tempfile.mkstemp(prefix='.school-cache-', dir=path.parent)
        with os.fdopen(descriptor, 'w', encoding='utf-8') as stream:
            json.dump(record, stream, ensure_ascii=False)
        os.replace(temporary, path)
        temporary = None
        entries = sorted(path.parent.glob('school-*.json'), key=lambda item: item.stat().st_mtime_ns)
        for old in entries[:-64]:
            if old != path and old.is_file() and not old.is_symlink():
                old.unlink()
    except OSError:
        pass  # Failed caching never substitutes for failed or skipped verification.
    finally:
        if temporary and os.path.exists(temporary):
            os.unlink(temporary)


# Source: format_preamble.py
"""Private, bounded compiler preambles; each reader owns its artifact lifetime."""
SCHOOL_PREAMBLE_CACHE_VERSION = 5
SCHOOL_PREAMBLE_CACHE_ENTRIES = 8
SCHOOL_PREAMBLE_CACHE_BYTES = 256 * 1024 * 1024


def school_preamble_cache_key(source, prefix, compiler, arguments):
    record = dict(version=SCHOOL_PREAMBLE_CACHE_VERSION, directory=str(source.parent),
                  prefix=prefix, compiler=format_file_identity(compiler), arguments=arguments,
                  cwd=str(Path.cwd()),
                  environment={name: os.environ.get(name) for name in SCHOOL_FRONTEND_ENVIRONMENT})
    return hashlib.sha256(json.dumps(record, sort_keys=True).encode()).hexdigest()


def school_preamble_cache_root(source):
    record = format_cache_location(source, {})
    if record is None:
        return None
    root = record.parent / 'preambles'
    try:
        root.mkdir(mode=0o700, exist_ok=True)
        info = root.stat()
        if root.is_symlink() or info.st_uid != os.getuid() or info.st_mode & 0o022:
            return None
    except OSError:
        return None
    return root


def school_preamble_blob_name(key, value):
    return (isinstance(value, str) and Path(value).name == value and
            re.fullmatch(r'pch-' + re.escape(key) + r'-[\w-]+\.pch', value) is not None)


def school_preamble_blob_info(value):
    info = Path(value).stat()
    if (not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o022
            or Path(value).is_symlink()):
        raise ValueError('untrusted preamble artifact')
    # Reader hardlinks change ctime/link count, but never artifact bytes.
    return [info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns]


def school_preamble_link(original, destination):
    try:
        os.link(original, destination)
    except OSError:
        shutil.copyfile(original, destination)


def school_preamble_cache_load(source, prefix, key):
    root = school_preamble_cache_root(source)
    if root is None:
        return None
    temporary = None
    try:
        index = root / (key + '.json')
        if index.is_symlink() or index.stat().st_size > 4 * 1024 * 1024:
            return None
        record = json.loads(index.read_text())
        if (record.get('version') != SCHOOL_PREAMBLE_CACHE_VERSION or record.get('key') != key
                or record.get('clock_independent') is not True
                or not school_preamble_blob_name(key, record.get('blob'))
                or not isinstance(record.get('dependencies'), dict)
                or not isinstance(record.get('inputs'), list)
                or not isinstance(record.get('prefix'), str) or not record['prefix']
                or not prefix.startswith(record['prefix'])
                or not isinstance(record.get('lookup_roots'), list)
                or any(not isinstance(value, list) or len(value) != 2
                       or not isinstance(value[0], str) or not Path(value[0]).is_absolute()
                       or type(value[1]) is not bool for value in record['lookup_roots'])
                or any(value not in record['dependencies'] for value in record['inputs'])):
            return None
        dependencies = record['dependencies']
        if any(not Path(value).is_absolute() or format_file_identity(value) != identity
               for value, identity in dependencies.items()):
            return None
        blob = root / record['blob']
        if school_preamble_blob_info(blob) != record.get('artifact'):
            return None
        temporary = tempfile.TemporaryDirectory(prefix='cp-format-preamble-')
        target = Path(temporary.name) / 'prefix.pch'
        school_preamble_link(blob, target)
        # An evicted blob can disappear before linking; an active reader's
        # private link/copy remains valid throughout compiler execution.
        if school_preamble_blob_info(blob) != record['artifact'] or target.stat().st_size != record['artifact'][2]:
            temporary.cleanup()
            return None
        os.utime(index, None)
        return dict(temporary=temporary, pch=str(target), prefix=record['prefix'],
                    dependencies=record['inputs'], identities=dependencies, cache_key=key,
                    lookup_roots=[tuple(value) for value in record['lookup_roots']], lookup_complete=True)
    except (OSError, ValueError, KeyError, TypeError, AttributeError):
        if temporary is not None:
            temporary.cleanup()
        return None


def school_preamble_cache_prune(root):
    """Called under the publisher lock; loaded readers already own their link."""
    records = sorted(root.glob('*.json'), key=lambda value: value.stat().st_mtime_ns, reverse=True)
    retained, total = set(), 0
    for index in records:
        if not re.fullmatch(r'[0-9a-f]{64}\.json', index.name):
            continue
        try:
            record = json.loads(index.read_text())
            blob = root / record['blob']
            if not school_preamble_blob_name(index.stem, blob.name):
                raise ValueError('invalid preamble blob')
            size = blob.stat().st_size
            if len(retained) >= SCHOOL_PREAMBLE_CACHE_ENTRIES or total + size > SCHOOL_PREAMBLE_CACHE_BYTES:
                index.unlink()
            else:
                retained.add(blob.name)
                total += size
        except (OSError, ValueError, KeyError, TypeError):
            index.unlink(missing_ok=True)
    for blob in root.glob('pch-*.pch'):
        if re.fullmatch(r'pch-[0-9a-f]{64}-[\w-]+\.pch', blob.name) and blob.name not in retained:
            blob.unlink(missing_ok=True)


def school_preamble_cache_store(source, key, entry):
    root = school_preamble_cache_root(source)
    if root is None or Path(entry['pch']).stat().st_size > SCHOOL_PREAMBLE_CACHE_BYTES:
        return
    descriptor, blob, temporary = None, None, None
    try:
        # No waiting behind another process: a preparation cache is optional.
        descriptor = os.open(root / '.lock', os.O_RDWR | os.O_CREAT | getattr(os, 'O_NOFOLLOW', 0), 0o600)
        info = os.fstat(descriptor)
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o022:
            return
        fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
        old = root / (key + '.json')
        handle, name = tempfile.mkstemp(prefix='pch-' + key + '-', suffix='.pch', dir=root)
        os.close(handle)
        blob = Path(name)
        blob.unlink()
        school_preamble_link(entry['pch'], blob)
        os.chmod(blob, 0o600)
        record = dict(version=SCHOOL_PREAMBLE_CACHE_VERSION, key=key, clock_independent=True, blob=blob.name,
                      artifact=school_preamble_blob_info(blob), dependencies=entry['identities'],
                      inputs=entry['dependencies'], prefix=entry['prefix'], lookup_roots=entry['lookup_roots'])
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', prefix='.index-', dir=root, delete=False) as stream:
            temporary = Path(stream.name)
            json.dump(record, stream)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, old)
        temporary, blob = None, None
        school_preamble_cache_prune(root)
    except (OSError, ValueError, TypeError):
        pass  # Full parsing is still mandatory if preparation cannot be reused.
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
        if blob is not None:
            blob.unlink(missing_ok=True)
        if descriptor is not None:
            os.close(descriptor)


# Source: school_compiler.py
"""Structured GNU diagnostics preserve the syntax gate without duplicate builds."""
from urllib.parse import unquote as school_unquote, urlsplit as school_urlsplit


def school_gcc_diagnostic_option(banner):
    version = re.search(r'\b(\d+)\.\d+(?:\.\d+)?\b', banner)
    if version is None or int(version[1]) < 9:
        return None
    # GCC 16 removed its old JSON format; SARIF keeps the warning rule identity.
    return '-fdiagnostics-format=' + ('sarif-stderr' if int(version[1]) >= 16 else 'json')


def school_gcc_diagnostics(text):
    """Return (only promoted warnings, human text), or None for unknown output."""
    try:
        record = json.loads(text)
        messages = []
        if isinstance(record, list):
            def visit(item):
                kind, message = item['kind'], item['message']
                if kind not in ('error', 'fatal error', 'warning', 'note', 'sorry, unimplemented') or not isinstance(message, str):
                    raise ValueError('unsupported GNU diagnostic')
                locations = item.get('locations', [])
                caret = locations[0].get('caret', {}) if locations else {}
                messages.append((kind, item.get('option', ''), message, caret.get('file', ''),
                                 caret.get('line', 1), caret.get('display-column', caret.get('column', 1))))
                for child in item.get('children', []):
                    visit(child)
            for item in record:
                visit(item)
        elif isinstance(record, dict) and record.get('version') == '2.1.0' and isinstance(record.get('runs'), list):
            for run in record['runs']:
                # Tool crashes/incomplete results must retain the conservative gate.
                for invocation in run.get('invocations', []):
                    arguments = invocation.get('arguments', [])
                    if (invocation.get('toolExecutionNotifications') or '-Wfatal-errors' in arguments
                            or any(arg.startswith('-fmax-errors=') and arg != '-fmax-errors=0' for arg in arguments)):
                        return None
                for item in run.get('results', []):
                    kind, rule = item.get('level'), item.get('ruleId', '')
                    if kind not in ('error', 'warning', 'note'):
                        return None
                    location = next(iter(item.get('locations', [])), {}).get('physicalLocation', {})
                    uri = location.get('artifactLocation', {}).get('uri', '')
                    filename = school_unquote(school_urlsplit(uri).path) if uri.startswith('file:') else school_unquote(uri)
                    region = location.get('region', {})
                    message = item['message']['text']
                    if not isinstance(message, str):
                        return None
                    messages.append((kind, rule, message, filename, region.get('startLine', 1),
                                     region.get('startColumn', 1)))
                    for related in item.get('relatedLocations', []):
                        detail = related.get('message', {}).get('text', '')
                        if detail:
                            messages.append(('note', '', detail, '', 1, 1))
        else:
            return None
        errors = [item for item in messages if item[0] in ('error', 'fatal error', 'sorry, unimplemented')]
        only_warnings = bool(errors) and all(isinstance(item[1], str) and item[1].startswith('-Werror=') for item in errors)
        lines = []
        for kind, option, message, filename, line, column in messages:
            if not isinstance(filename, str) or type(line) is not int or type(column) is not int:
                return None
            prefix = '{}:{}:{}: '.format(filename, line, column) if filename else ''
            suffix = ' [' + option + ']' if isinstance(option, str) and option.startswith('-W') else ''
            lines.append(prefix + kind + ': ' + message + suffix)
        return only_warnings, '\n'.join(lines)
    except (ValueError, KeyError, TypeError, AttributeError, IndexError):
        return None


def school_gcc_check(argv, flags, output, dependency, banner):
    """Run every canonical flag; skip syntax-only only with positive warning evidence."""
    options = ['-c', '-MD', '-MF', str(dependency), '-MT', 'cp_source', '-o', str(output)]
    diagnostic = school_gcc_diagnostic_option(banner)
    checked = school_tool([*argv, *flags, *([diagnostic] if diagnostic else []), *options],
                          capture_output=True, text=True)
    structured = school_gcc_diagnostics(checked.stderr) if diagnostic else None
    if diagnostic and structured is None:
        # Older/custom compiler wrappers may not implement the advertised format.
        checked = school_tool([*argv, *flags, *options], capture_output=True, text=True)
    elif structured is not None:
        only_warnings, rendered = structured
        checked.stderr = rendered
        if checked.returncode == 1 and only_warnings:
            return checked, True
    return checked, False


# Source: school_format.py
"""School policy checks over Clang's parsed source; no candidate is executed."""

SCHOOL_STYLE = {
    'BasedOnStyle': 'LLVM', 'IndentWidth': 4, 'ContinuationIndentWidth': 8,
    'ColumnLimit': 100, 'UseTab': 'Never', 'BreakBeforeBraces': 'Attach',
    'AlwaysBreakAfterReturnType': 'AllDefinitions', 'AlignAfterOpenBracket': 'DontAlign',
    'IndentCaseLabels': False, 'IndentGotoLabels': False, 'PointerAlignment': 'Right',
    'DerivePointerAlignment': False, 'SpaceAfterCStyleCast': True, 'InsertBraces': True,
    'AllowShortFunctionsOnASingleLine': 'None', 'AllowShortLoopsOnASingleLine': False,
    'AllowShortIfStatementsOnASingleLine': 'Never', 'BinPackParameters': False,
    'SortIncludes': 'Never', 'BreakStringLiterals': False, 'AllowShortEnumsOnASingleLine': False,
    'CommentPragmas': '^ *school-(reviewed|justified|warning)',
}


def school_prepare(source, text, clang, tree=None):
    """Plan only parsed, local parameter/body edits; retain original expressions."""
    if tree is None:
        tree, issues = school_parse(source, text, clang)
        if issues:
            return text, issues
    data = text.encode('utf-8')
    tokens = school_tokens(text)
    edits = []
    probe = SchoolPolicy(source, text, tree)
    # Calls supplying arguments to a prototype-less definition need an author
    # decision before a void signature can be introduced.
    with_arguments = {probe.canonical_declaration(probe.callee_declaration(node).get('id')) for node in school_nodes(tree)
                      if node.get('kind') == 'CallExpr' and len(node.get('inner', [])) > 1}
    for node in school_definitions(tree):
        parameters = school_definition_parameters(text, node, tokens)
        if not parameters or probe.canonical_declaration(node.get('id')) in with_arguments:
            continue
        opening, closing = parameters
        if closing == opening + 1:
            position = len(text[:tokens[closing][1]].encode('utf-8'))
            edits.append((position, position, b'void'))
    for position in school_empty_body_positions(text, tree):
        offset = len(text[:position].encode('utf-8'))
        edits.append((offset, offset + 1, b'{}'))
    for start, end, replacement in sorted(set(edits), reverse=True):
        data = data[:start] + replacement + data[end:]
    return data.decode('utf-8'), []



def school_nodes(node):
    yield node
    for child in node.get('inner', []):
        yield from school_nodes(child)


def school_gcc_arguments(source, path, directory, gcc, tree):
    language = 'c' if source.suffix in ('.c', '.h') else 'c++'
    flags = list(SCHOOL_C_FLAGS if language == 'c' else SCHOOL_CPP_FLAGS)
    driver = gcc
    if language == 'c++':
        driver = shutil.which(str(Path(gcc).with_name(Path(gcc).name.replace('gcc', 'g++')))) or gcc
    input_path, includes = path, []
    if source.suffix in ('.h', '.hpp'):
        input_path = Path(directory) / ('unit.c' if language == 'c' else 'unit.cpp')
        input_path.write_text('')
        includes = ['-include', str(path)]
    main = tree is not None and any(n.get('kind') == 'FunctionDecl' and n.get('name') == 'main'
                                   for n in tree.get('inner', []))
    # Other project implementations are outside this formatting action. Compile
    # this unit; the read-only Makefile audit owns the complete-link obligation.
    project = any(item[1] == '"' and (source.parent / item[2]).is_file()
                  for item in school_includes(path.read_text()))
    main = main and not project
    argv = [driver, '-x', language, *includes, str(input_path), '-iquote', str(source.parent)]
    return argv, flags, main, input_path, includes


def school_syntax_gate(argv, flags):
    syntax = [flag for flag in flags if flag != '-Werror']
    return school_tool([*argv, *syntax, '-w', '-fsyntax-only'], text=True, capture_output=True)


def school_publish(jobs, identities=None):
    for source, original, _ in jobs:
        if source.read_bytes() != original:
            raise CheckSetupError('source changed during formatting: ' + str(source))
        current = source.stat()
        if identities and identities[source] != (current.st_dev, current.st_ino):
            raise CheckSetupError('source was replaced during formatting: ' + str(source))
    published = []
    for source, original, candidate in jobs:
        if original == candidate:
            continue
        temporary = None
        try:
            descriptor, temporary = tempfile.mkstemp(prefix='.cp-format-', dir=source.parent)
            with os.fdopen(descriptor, 'wb') as stream:
                stream.write(candidate)
            os.chmod(temporary, source.stat().st_mode & 0o777)
            os.replace(temporary, source)
            published.append(str(source))
        except OSError as error:
            previous = '\nAlready formatted: ' + ', '.join(published) if published else '\nNo files were published.'
            raise CheckSetupError('cannot publish formatted file ' + str(source) + ': ' + str(error) + previous) from error
        finally:
            if temporary and os.path.exists(temporary):
                os.unlink(temporary)


def school_analyze(config):
    """Publish safe layout first; unresolved obligations still return failure."""
    clang = shutil.which('clang')
    formatter = shutil.which(config.get('native_formatter', 'clang-format'))
    gcc = shutil.which(os.environ.get('CP_RUN_GCC', 'gcc-16')) or shutil.which('gcc')
    if not all((clang, formatter, gcc)):
        raise CheckSetupError('school needs clang-format, clang (AST) and GNU GCC.')
    banner = school_tool([gcc, '--version'], capture_output=True, text=True)
    if banner.returncode or 'clang' in banner.stdout.lower() or not re.search(r'GNU|gcc|g\+\+', banner.stdout):
        raise CheckSetupError('school needs GNU GCC; set CP_RUN_GCC to its executable.')
    jobs, diagnostics, identities, cache_jobs, inputs = [], [], {}, [], set()
    for value in dict.fromkeys(format_source_list(config)):
        source = Path(value).resolve()
        if source.suffix not in ('.c', '.h', '.hpp', '.cc', '.cpp', '.cxx', '.C'):
            raise CheckUsageError('school supports C and C++ sources only')
        original = source.read_bytes()
        metadata = source.stat()
        identities[source] = metadata.st_dev, metadata.st_ino
        try:
            text = original.decode('utf-8')
        except UnicodeDecodeError as error:
            raise CheckSetupError(str(source) + ': school: expected UTF-8 source: ' + str(error)) from error
        clean = format_strip_automatic(text)
        cpp_driver = shutil.which(str(Path(gcc).with_name(Path(gcc).name.replace('gcc', 'g++')))) or gcc
        tools = [clang, formatter, gcc, cpp_driver]
        cached = format_cache_load(source, clean, tools, config)
        if cached is not None:
            diagnostics.extend(cached[0])
            inputs.update(cached[1])
            jobs.append((source, original, clean.encode('utf-8')))
            continue
        cpp = source.suffix not in ('.c', '.h')
        language = 'c++' if cpp else 'c'
        search = [*school_header_search(cpp_driver if cpp else gcc, language),
                  *school_header_search(clang, language,
                      [*(school_cpp_context() if cpp else []), '-iquote', str(source.parent)])]
        original_tree, parse_issues = school_parse(source, clean, clang)
        candidate, issues = clean, []
        if original_tree is not None:
            candidate, issues = school_prepare(source, clean, clang, original_tree)
        style = dict(SCHOOL_STYLE)
        if original_tree is None:
            style['InsertBraces'] = False
        formatted = school_tool([formatter, '--style=' + json.dumps(style),
            '--assume-filename=' + str(source)], input=candidate, text=True, capture_output=True)
        if formatted.returncode:
            raise CheckSetupError(formatted.stderr)
        candidate = formatted.stdout
        tree = None
        parser_locations_current = candidate == clean
        if original_tree is not None:
            candidate, tree, final_parse = school_apply_layout(source, candidate, clang, original_tree if candidate == clean else None)
            if tree is None:
                raise CheckSetupError(str(source) + ': school: candidate failed parsing:\n' + '\n'.join(final_parse))
            school_verify_layout(source, clean, original_tree, candidate, tree)
            policy = SchoolPolicy(source, candidate, tree)
            issues.extend(policy.run())
        else:
            if [token for token, _ in school_tokens(clean)] != [token for token, _ in school_tokens(candidate)]:
                raise CheckSetupError(str(source) + ': school: unsupported syntax prevents verifying token changes.')
            if candidate != clean:
                parsed_candidate, current_issues = school_parse(source, candidate, clang)
                if parsed_candidate is None:
                    parse_issues = current_issues
                    parser_locations_current = True
            issues.append(FormatFinding(source, 1, 1, 'frontend', 'error',
                          'token layout only; AST checks unavailable: Clang could not parse this source.\n' + '\n'.join(parse_issues)))
        dependency_identities = original_tree.get('school_dependency_identities', {}) if original_tree else getattr(parse_issues, 'identities', {})
        dependencies = list(tree.get('school_dependencies', [])) if tree is not None else list(getattr(parse_issues, 'dependencies', []))
        with tempfile.TemporaryDirectory(prefix='cp-school-') as directory:
            path = Path(directory) / source.name
            path.write_text(candidate)
            argv, flags, main, input_path, includes = school_gcc_arguments(source, path, directory, gcc, tree)
            output = str(Path(directory) / 'verify.out')
            dependency = Path(directory) / 'gcc.d'
            checked, warning_failure = school_gcc_check(argv, flags, output, dependency, banner.stdout)
            if dependency.exists():
                dependencies.extend(value for value in format_dependency_paths(dependency.read_text())
                                    if not Path(value).is_relative_to(directory))
            if checked.returncode:
                syntax = None if warning_failure else school_syntax_gate(argv, flags)
                if syntax is not None and syntax.returncode:
                    raise CheckSetupError(str(source) + ': school: syntax prevents safe publication:\n' +
                                          syntax.stderr.replace(str(path), str(source)))
                issues.append(FormatFinding(source, 1, 1, 'GCC', 'error', 'fix compiler diagnostics:\n' +
                              checked.stderr.replace(str(path), str(source))))
            if tree is not None and school_needs_resource_analysis(source, candidate, tree):
                for finding in school_resource_analysis(source, path, input_path, clang, includes):
                    if finding.source != str(source) or (finding.rule, finding.line) not in policy.error_justifications:
                        issues.append(finding)
        dependencies = set(dependencies) | {str(source.with_suffix('.h')),
                       str(source.parent / 'Makefile'), str(source.parent / 'makefile')}
        snapshot = None
        if config.get('format_cache', True):
            try:
                prepared = original_tree.get('school_prepared_lookup') if original_tree is not None else None
                reusable = prepared and candidate.startswith(prepared['prefix']) and set(search) <= set(prepared['roots'])
                body = candidate[len(prepared['prefix']):] if reusable else candidate
                # Conditional/file directives need a full lookup graph; common
                # body edits only add definitions after the prepared includes.
                if reusable:
                    for start, stop in school_directive_spans(body):
                        directive = re.match(r'\s*#\s*(\w+)', body[start:stop])
                        if directive is None or directive[1] not in ('define', 'undef'):
                            reusable = False
                    reusable = reusable and '__has_' not in body and '_Pragma' not in body and '%:' not in body
                if reusable:
                    positive = {prepared['identities'][value][0] for value in prepared['inputs']
                                if prepared['identities'].get(value) is not None}
                    extra = [value for value in dependencies
                             if Path(value).is_file() and str(Path(value).resolve()) not in positive]
                    expanded = dependencies | set(prepared['identities'])
                    expanded.update(format_include_candidates(source, body, dependencies, search, owners=extra))
                    snapshot = dict(prepared['identities'])
                    for value in expanded - snapshot.keys():
                        snapshot[value] = format_file_identity(value)
                else:
                    expanded = dependencies | format_include_candidates(source, candidate, dependencies, search)
                    snapshot = {value: format_file_identity(value) for value in expanded}
                dependencies = expanded
            except (OSError, ValueError):
                pass  # Unusable speculative include paths disable optional result caching.
        for dependency_name, identity in dependency_identities.items():
            if format_file_identity(dependency_name) != identity:
                raise CheckSetupError('dependency changed during formatting: ' + dependency_name)
        inputs.update(dependencies)
        inputs.update(str(value) for value in (source.with_suffix('.h'), source.parent / 'Makefile', source.parent / 'makefile'))
        # A backend limitation remains an error in the cache; only unchanged
        # layout is eligible so parser locations still describe the source.
        if snapshot is not None and (tree is not None or parser_locations_current):
            cache_jobs.append((source, candidate, list(issues), snapshot, tools))
        diagnostics.extend(issues)
        jobs.append((source, original, candidate.encode('utf-8')))
    return FormatResult(diagnostics, jobs, identities, cache_jobs, list(inputs))


def execute_school_format(config):
    return execute_format_review(dict(config, format_mode='school'))


# Source: school_frontend.py
"""GNU-compatible Clang parsing with dependency-validated precompiled preambles."""
SCHOOL_CPP_CONTEXTS = {}
SCHOOL_HEADER_SEARCHES = {}
SCHOOL_CONFIGURATION_INPUTS = set()
SCHOOL_PREAMBLES = {}
SCHOOL_FRONTEND_ENVIRONMENT = (
    'CPATH', 'C_INCLUDE_PATH', 'CPLUS_INCLUDE_PATH', 'SDKROOT', 'DEVELOPER_DIR',
    'GCC_EXEC_PREFIX', 'COMPILER_PATH', 'SOURCE_DATE_EPOCH', 'LANG', 'LC_ALL',
)


class SchoolParseIssues(list):
    def __init__(self, messages=(), dependencies=()):
        super().__init__(messages)
        self.dependencies = list(dependencies)
        self.identities = {value: format_file_identity(value) for value in self.dependencies}



def school_header_search(compiler, language, arguments=()):
    """Read real search roots, including framework and nonexistent env roots."""
    key = (str(Path(compiler).resolve()), tuple(format_file_identity(compiler) or ()),
           language, tuple(arguments), str(Path.cwd()),
           tuple(os.environ.get(name) for name in SCHOOL_FRONTEND_ENVIRONMENT))
    if key not in SCHOOL_HEADER_SEARCHES:
        probe = school_tool([compiler, '-E', '-x', language, '-v', *arguments, '-'],
                            input='', text=True, capture_output=True, env=dict(os.environ, LC_ALL='C'))
        paths, inside = [], False
        if not probe.returncode:
            for line in probe.stderr.splitlines():
                value = line.strip()
                if value in ('#include <...> search starts here:', '#include "..." search starts here:'):
                    inside = True
                    continue
                if value == 'End of search list.':
                    break
                if inside and value:
                    framework = value.endswith(' (framework directory)')
                    path = value.removesuffix(' (framework directory)')
                    paths.append((str(Path(path).absolute()), framework))
        # SDK configuration is an input, but it is not an include-search root.
        # Keep its file identity without projecting every header through it.
        for line in probe.stderr.splitlines():
            try:
                words = shlex.split(line)
            except ValueError:
                continue
            for word in words:
                if word.startswith('-fdepfile-entry='):
                    value = Path(word.split('=', 1)[1]).absolute()
                    SCHOOL_CONFIGURATION_INPUTS.update((str(value), str(value.resolve())))
        for name in ('CPATH', 'CPLUS_INCLUDE_PATH' if language == 'c++' else 'C_INCLUDE_PATH'):
            if name in os.environ:
                paths.extend((str(Path(value or '.').absolute()), False)
                             for value in os.environ[name].split(os.pathsep))
        SCHOOL_HEADER_SEARCHES[key] = list(dict.fromkeys(paths))
    return SCHOOL_HEADER_SEARCHES[key]


def school_cpp_context():
    """Query the selected GNU driver; never mix its headers with libc++."""
    gcc = shutil.which(os.environ.get('CP_RUN_GCC', 'gcc-16')) or shutil.which('gcc')
    if not gcc:
        return []
    driver = shutil.which(str(Path(gcc).with_name(Path(gcc).name.replace('gcc', 'g++')))) or gcc
    key = (str(Path(driver).resolve()), tuple(format_file_identity(driver) or ()),
           str(Path.cwd()), tuple(os.environ.get(name) for name in SCHOOL_FRONTEND_ENVIRONMENT))
    if key not in SCHOOL_CPP_CONTEXTS:
        paths = [str(Path(value).resolve()) for value, _ in school_header_search(driver, 'c++')
                 if '/c++/' in value and Path(value).is_dir()]
        SCHOOL_CPP_CONTEXTS[key] = ['-nostdinc++', *[arg for value in dict.fromkeys(paths)
                                                  for arg in ('-isystem', value)]] if paths else []
    return SCHOOL_CPP_CONTEXTS[key]


def school_preamble_prefixes(text):
    """End at the last balanced include, leaving later source macros editable."""
    code, end, depth, prefixes = school_mask(text), 0, 0, []
    pending_include = False
    for start, finish in school_directive_spans(text):
        if code[end:start].strip():
            break
        directive = re.match(r'\s*#\s*([A-Za-z_]\w*)', code[start:finish])
        if not directive or directive[1] == 'line':
            return []
        name = directive[1]
        if name in ('if', 'ifdef', 'ifndef'):
            depth += 1
        elif name == 'endif':
            depth -= 1
        if depth < 0:
            return []
        if name == 'include':
            pending_include = True
        end = finish
        if depth == 0 and pending_include:
            if school_includes(text[:end]):
                prefixes.append(text[:end])
            pending_include = False
    return prefixes



def school_preamble_prefix(text):
    prefixes = school_preamble_prefixes(text)
    return prefixes[-1] if prefixes else ''


def school_json_roots(output):
    decoder, roots, position = json.JSONDecoder(), [], 0
    while position < len(output):
        while position < len(output) and output[position].isspace():
            position += 1
        if position >= len(output):
            break
        value, position = decoder.raw_decode(output, position)
        roots.append(value)
    return roots



def school_ast_root(output):
    try:
        tree = json.loads(output)
    except (ValueError, TypeError) as error:
        raise CheckSetupError('school: Clang returned invalid AST JSON: ' + str(error)) from error
    if not isinstance(tree, dict) or tree.get('kind') != 'TranslationUnitDecl':
        raise CheckSetupError('school: Clang returned an unsupported AST root')
    return tree


def school_cpp_preamble(source, text, clang, args):
    prefix = school_preamble_prefix(text)
    if not prefix or format_volatile_inputs(prefix, []):
        return None
    key = (str(source.parent), prefix, tuple(args), tuple(format_file_identity(clang) or ()),
           str(Path.cwd()), tuple(os.environ.get(name) for name in SCHOOL_FRONTEND_ENVIRONMENT))
    entry = SCHOOL_PREAMBLES.get(key)
    if entry and all(format_file_identity(value) == identity for value, identity in entry['identities'].items()):
        return entry
    if entry:
        entry['temporary'].cleanup()
        del SCHOOL_PREAMBLES[key]
    search = school_header_search(clang, 'c++', [*args, '-iquote', str(source.parent)])
    gcc = shutil.which(os.environ.get('CP_RUN_GCC', 'gcc-16')) or shutil.which('gcc')
    if gcc:
        driver = shutil.which(str(Path(gcc).with_name(Path(gcc).name.replace('gcc', 'g++')))) or gcc
        search = list(dict.fromkeys([*search, *school_header_search(driver, 'c++')]))
    cache_key = school_preamble_cache_key(source, prefix, clang, ['clang-pch', *args, search])
    restored = school_preamble_cache_load(source, prefix, cache_key)
    if restored is not None:
        SCHOOL_PREAMBLES[key] = restored
        school_preamble_trim()
        return restored
    temporary = tempfile.TemporaryDirectory(prefix='cp-format-preamble-')
    pch, dependency = Path(temporary.name) / 'prefix.pch', Path(temporary.name) / 'prefix.d'
    prefixes = school_preamble_prefixes(text)
    attempts = list(dict.fromkeys([prefix, prefixes[0]]))
    for prepared in attempts:
        result = school_tool([clang, '-x', 'c++-header', '-std=gnu++17', *args,
                             '-iquote', str(source.parent), '-MD', '-MF', str(dependency),
                             '-MT', 'cp_source', '-o', str(pch), '-'],
                            input=prepared, text=True, capture_output=True)
        if not result.returncode and pch.is_file() and dependency.is_file():
            break
    else:
        temporary.cleanup()
        return None
    dependencies = [str(Path(value).absolute()) for value in format_dependency_paths(dependency.read_text())]
    if format_volatile_inputs(prefix, dependencies):
        temporary.cleanup()
        return None
    dependencies = list(dict.fromkeys(dependencies))
    cacheable = True
    try:
        watched = set(dependencies) | format_include_candidates(source, prefix, dependencies, search)
        identities = {value: format_file_identity(value) for value in watched}
    except (OSError, ValueError):
        # Still use this invocation's PCH; unknown lookup alternatives only
        # prevent reuse, not full source analysis.
        identities = {value: format_file_identity(value) for value in dependencies}
        cacheable = False
    entry = dict(temporary=temporary, pch=str(pch), prefix=prepared,
                 dependencies=dependencies, identities=identities, lookup_roots=search, lookup_complete=cacheable)
    if cacheable:
        school_preamble_cache_store(source, cache_key, entry)
        SCHOOL_PREAMBLES[key] = entry
        school_preamble_trim()
    return entry


def school_preamble_trim():
    while len(SCHOOL_PREAMBLES) > 4:
        key = next(iter(SCHOOL_PREAMBLES))
        SCHOOL_PREAMBLES.pop(key)['temporary'].cleanup()


def school_preamble_input(text, entry):
    # Mask bytes, not Unicode code points: AST offsets are UTF-8 byte offsets.
    prefix = entry['prefix'].encode('utf-8')
    blank = bytes(byte if byte in (10, 13) else 32 for byte in prefix)
    return (blank + text.encode('utf-8')[len(prefix):]).decode('utf-8')


def school_query_ast(source, text, clang, args, entry, name, appended=''):
    result = school_tool([clang, '-x', 'c++', '-std=gnu++17', *args,
                         '-iquote', str(source.parent), '-include-pch', entry['pch'],
                         '-Xclang', '-ast-dump=json', '-Xclang', '-ast-dump-filter=' + name,
                         '-fsyntax-only', '-'],
                        input=school_preamble_input(text, entry) + appended,
                        text=True, capture_output=True)
    if result.returncode:
        return None
    try:
        return school_json_roots(result.stdout)
    except (ValueError, TypeError):
        return None


def school_preamble_semantics(source, text, clang, args, entry, tree):
    """Recover only used external enum values and catch ancestry, not header bodies."""
    local_ids = {node.get('id') for node in school_nodes(tree) if node.get('kind') == 'EnumConstantDecl'}
    references = {}
    catch_types = set()
    for node in school_nodes(tree):
        reference = node.get('referencedDecl', {})
        if reference.get('kind') == 'EnumConstantDecl' and reference.get('id') not in local_ids:
            references[reference['id']] = reference
        if node.get('kind') == 'CXXTryStmt':
            handlers = [child for child in node.get('inner', []) if child.get('kind') == 'CXXCatchStmt']
            if len(handlers) > 1:
                for handler in handlers:
                    for child in handler.get('inner', []):
                        if child.get('kind') == 'VarDecl':
                            typ = child.get('type', {}).get('desugaredQualType', child.get('type', {}).get('qualType', ''))
                            catch_types.add(re.sub(r'\bconst\b|[&* ]', '', typ))
    values = {}
    if references:
        tag = '__cp_format_value_' + hashlib.sha256(text.encode()).hexdigest()[:16]
        while tag in text:
            tag += '_'
        declarations = []
        identifiers = list(references)
        for index, reference in enumerate(references.values()):
            typ, name = reference.get('type', {}).get('qualType', ''), reference.get('name', '')
            if not re.fullmatch(r'[A-Za-z_]\w*(?:::[A-Za-z_]\w*)*', name):
                return False
            if '(unnamed enum' in typ or '(anonymous enum' in typ:
                scope = typ.split('(', 1)[0].rstrip(': ')
                expression = (scope + '::' if scope else '') + name
            elif re.fullmatch(r'[A-Za-z_]\w*(?:::[A-Za-z_]\w*)*', typ):
                expression = typ + '::' + name
            else:
                return False
            declarations.append('enum { ' + tag + str(index) +
                                ' = static_cast<__underlying_type(decltype(' + expression + '))>(' + expression + ') };')
        roots = school_query_ast(source, text, clang, args, entry, tag, '\n' + '\n'.join(declarations) + '\n')
        if roots is None:
            return False
        for root in roots:
            name = root.get('name', '')
            if root.get('kind') == 'EnumConstantDecl' and name.startswith(tag):
                try:
                    index = int(name[len(tag):])
                    value = next(node['value'] for node in school_nodes(root)
                                 if node.get('kind') == 'ConstantExpr' and 'value' in node)
                    values[identifiers[index]] = int(value)
                except (ValueError, IndexError, StopIteration):
                    return False
        if len(values) != len(references):
            return False
    bases, pending = {}, list(catch_types)
    builtin = {'int', 'char', 'long', 'short', 'bool', 'float', 'double', 'unsigned', '...'}
    while pending:
        name = pending.pop()
        if name in bases or name in builtin:
            continue
        if len(bases) >= 32 or not re.fullmatch(r'[A-Za-z_]\w*(?:::[A-Za-z_]\w*)*', name):
            return False
        roots = school_query_ast(source, text, clang, args, entry, name)
        if roots is None:
            return False
        records = [node for root in roots for node in school_nodes(root)
                   if node.get('kind') == 'CXXRecordDecl' and node.get('completeDefinition')
                   and node.get('name') == name.rsplit('::', 1)[-1]]
        if len(records) != 1:
            return False
        inherited = [base.get('type', {}).get('desugaredQualType', base.get('type', {}).get('qualType', '')) for base in records[0].get('bases', [])]
        bases[name] = inherited
        bases.setdefault(records[0]['name'], inherited)
        pending.extend(inherited)
    tree['school_external_values'] = values
    tree['school_external_bases'] = bases
    return True


def school_frontend_parse(source, text, clang, cpp):
    args = school_cpp_context() if cpp else []
    entry = school_cpp_preamble(source, text, clang, args) if cpp else None
    with tempfile.TemporaryDirectory(prefix='cp-format-deps-') as directory:
        dependency = Path(directory) / 'source.d'
        invocation = [clang, '-x', 'c++' if cpp else 'c', '-std=gnu++17' if cpp else '-std=gnu99',
                      *args, '-iquote', str(source.parent), '-Xclang', '-ast-dump=json',
                      '-fsyntax-only', '-MD', '-MF', str(dependency), '-MT', 'cp_source']
        if cpp and entry is None and school_preamble_prefix(text):
            probe = school_tool([clang, '-x', 'c++', '-std=gnu++17', *args,
                                 '-iquote', str(source.parent), '-fsyntax-only', '-MD',
                                 '-MF', str(dependency), '-MT', 'cp_source', '-'],
                                input=text, text=True, capture_output=True)
            if probe.returncode:
                dependencies = format_dependency_paths(dependency.read_text()) if dependency.exists() else []
                return None, SchoolParseIssues([str(source) + ': school parser error:\n' + probe.stderr], dependencies)
        result = school_tool([*invocation, *(['-include-pch', entry['pch']] if entry else []), '-'],
                             input=school_preamble_input(text, entry) if entry else text,
                             text=True, capture_output=True)
        dependencies = format_dependency_paths(dependency.read_text()) if dependency.exists() else []
        if entry:
            dependencies = [value for value in dependencies if value != entry['pch']]
            dependencies.extend(entry['dependencies'])
        if entry:
            for value, identity in entry['identities'].items():
                if format_file_identity(value) != identity:
                    raise CheckSetupError('dependency changed during formatting: ' + value)
        if result.returncode:
            return None, SchoolParseIssues([str(source) + ': school parser error:\n' + result.stderr], dependencies)
        tree = school_ast_root(result.stdout)
        if entry and not school_preamble_semantics(source, text, clang, args, entry, tree):
            # An uncommon expression inaccessible to the small metadata probes
            # must receive full analysis, never an optimistic partial result.
            result = school_tool([*invocation, '-'], input=text, text=True, capture_output=True)
            if result.returncode:
                return None, SchoolParseIssues([str(source) + ': school parser error:\n' + result.stderr], dependencies)
            tree = school_ast_root(result.stdout)
            if dependency.exists():
                dependencies.extend(format_dependency_paths(dependency.read_text()))
            for value, identity in entry['identities'].items():
                if format_file_identity(value) != identity:
                    raise CheckSetupError('dependency changed during formatting: ' + value)
            entry = None
    reduced = school_reduce_tree(tree, list(dict.fromkeys(dependencies)))
    if entry:
        for value, identity in entry['identities'].items():
            if format_file_identity(value) != identity:
                raise CheckSetupError('dependency changed during formatting: ' + value)
        reduced['school_dependency_identities'].update(entry['identities'])
        if entry.get('lookup_complete'):
            reduced['school_prepared_lookup'] = dict(
                prefix=entry['prefix'], identities=entry['identities'],
                inputs=entry['dependencies'], roots=entry['lookup_roots'])
    return reduced, SchoolParseIssues()


# Source: school_policy.py
"""Per-rule school checks. Author review cannot suppress mechanical errors."""

import ast as school_python_ast

SCHOOL_RULES = (
    tuple('1.' + str(i) for i in range(1, 3)) +
    tuple('2.' + str(i) for i in range(1, 4)) +
    tuple('3.' + str(i) for i in range(1, 8)) +
    ('4.1', '4.2', '4.3') +
    tuple('4.4.' + str(i) for i in range(1, 6)) +
    tuple('4.5.' + str(i) for i in range(1, 4)) +
    tuple('4.6.' + str(i) for i in range(1, 13)) +
    tuple('4.7.' + str(i) for i in range(1, 10)) +
    tuple('5.' + str(i) for i in range(1, 19)) +
    tuple('6.' + str(i) for i in range(1, 7))
)
SCHOOL_REVIEW_RULES = {
    '3.1', '3.2', '3.4', '3.5', '3.7', '4.4.1', '4.4.4', '4.5.1',
    '4.6.11', '4.6.12', '4.7.9', '5.1', '5.2', '5.3', '5.4', '5.5', '5.6',
    '5.7', '5.8', '5.9', '5.10', '5.11', '5.12', '5.13', '5.14',
    '5.15', '5.17', '6.1', '6.4', '6.5', '6.6',
}
# Only these review cases have observable evidence. Semantic-only obligations
# remain documented; they must not produce blanket warnings.
SCHOOL_WARNING_RULES = {'3.2', '3.4', '3.5', '3.7', '4.4.4', '4.5.1',
                        '4.6.11', '5.2', '5.9', '5.12', '5.14'}
# A scanner keeps comments and literals out of directive/code checks.
SCHOOL_LEXER = re.compile(
    r'(?P<raw>(?:u8|[uUL])?R"(?P<raw_delimiter>[^ ()\\\t\r\n]{0,16})'
    r'\(.*?\)(?P=raw_delimiter)")|'
    r'(?P<comment>/\*.*?\*/|//(?:[^\r\n\\]|\\[^\r\n]|\\(?:\r\n|\r|\n))*)|'
    r'(?P<string>(?:u8|[uUL])?"(?:\\.|[^"\\])*")|'
    r"(?P<char>(?<![\w.])(?:u8|[uUL])?'(?:\\.|[^'\\])*')", re.S)
SCHOOL_STANDARD_HEADERS = set((
    'assert.h complex.h ctype.h errno.h fenv.h float.h inttypes.h iso646.h limits.h '
    'locale.h math.h setjmp.h signal.h stdalign.h stdarg.h stdatomic.h stdbool.h '
    'stddef.h stdint.h stdio.h stdlib.h stdnoreturn.h string.h tgmath.h threads.h '
    'time.h uchar.h wchar.h wctype.h unistd.h fcntl.h stdio_ext.h'
).split())
SCHOOL_OUTPUT_CALLS = {'printf', 'fprintf', 'vprintf', 'vfprintf', 'puts', 'fputs',
                       'putchar', 'putc', 'fputc', 'write', 'dprintf', 'perror'}
SCHOOL_ALLOCATORS = {'malloc', 'calloc', 'realloc'}
SCHOOL_UNSAFE_CALLS = {'gets', 'sprintf', 'strcpy', 'strcat', 'strncpy', 'strncat'}


def school_mask(text):
    return SCHOOL_LEXER.sub(
        lambda match: ''.join('\n' if c == '\n' else ' ' for c in match[0]), text)


def school_parse(source, text, clang, cpp=None):
    if cpp is None:
        cpp = source.suffix not in ('.c', '.h')
    return school_frontend_parse(source, text, clang, cpp)


def school_reduce_tree(tree, dependencies):
    # Header implementations are not part of the selected source. References
    # retain their name/type descriptors; project headers are audited separately.
    tree['school_dependencies'] = dependencies
    tree['school_dependency_identities'] = {value: format_file_identity(value) for value in dependencies}
    kept, external_enums, external_bases = [], [], dict(tree.get('school_external_bases', {}))
    for node in tree.get('inner', []):
        if 'includedFrom' not in school_location(node) and not node.get('isImplicit'):
            kept.append(node)
            continue
        # Keep semantic summaries needed by source expressions, not complete
        # header implementations. Enum values and exception ancestry are inputs.
        for child in school_nodes(node):
            if child.get('kind') == 'EnumDecl':
                external_enums.append(child)
            elif child.get('kind') == 'CXXRecordDecl' and child.get('completeDefinition'):
                external_bases[child.get('name')] = [
                    base.get('type', {}).get('desugaredQualType', base.get('type', {}).get('qualType', '')) for base in child.get('bases', [])]
    tree['school_external_enums'] = external_enums
    tree['school_external_bases'] = external_bases
    tree['inner'] = kept
    return tree


def school_tool(argv, **options):
    try:
        return subprocess.run(argv, timeout=60, **options)
    except subprocess.TimeoutExpired as error:
        raise CheckSetupError('school: tool timed out: ' + str(argv[0])) from error


def school_location(node):
    location = node.get('loc') or node.get('range', {}).get('begin', {})
    return location.get('expansionLoc', location)


def school_unwrap(node):
    while node.get('kind') in ('ImplicitCastExpr', 'ParenExpr', 'ConstantExpr',
                               'ExprWithCleanups', 'MaterializeTemporaryExpr'):
        children = node.get('inner', [])
        if len(children) != 1:
            break
        node = children[0]
    return node



def school_integer(node, constants):
    if not node:
        return None
    node = school_unwrap(node)
    if node.get('kind') in ('IntegerLiteral', 'CharacterLiteral', 'ConstantExpr') and 'value' in node:
        try:
            return int(node['value'])
        except ValueError:
            return None
    node = school_unwrap(node)
    if node.get('kind') == 'DeclRefExpr':
        return constants.get(node.get('referencedDecl', {}).get('id'))
    inner = node.get('inner', [])
    if node.get('kind') in ('CStyleCastExpr', 'UnaryOperator') and len(inner) == 1:
        value = school_integer(inner[0], constants)
        if value is not None:
            if node.get('kind') == 'CStyleCastExpr':
                return value
            if node.get('opcode') == '-':
                return -value
            if node.get('opcode') == '+':
                return value
    if node.get('kind') == 'BinaryOperator' and len(inner) == 2:
        left, right = (school_integer(child, constants) for child in inner)
        if left is not None and right is not None:
            operation = node.get('opcode')
            if operation == '+': return left + right
            if operation == '-': return left - right
            if operation == '*': return left * right
    return None


def school_transliteration(name):
    """Whole-word evidence; deliberately avoid broad substrings and dictionaries."""
    words = re.findall(r'[a-z]+', re.sub(r'([a-z])([A-Z])', r'\1_\2', name).lower())
    distinctive = {'vychislenie', 'vychislit', 'kolichestvo', 'znachenie', 'sleduyushchiy', 'predydushchiy'}
    russian = distinctive | {'chislo', 'chisla', 'massiv', 'razmer', 'dlina', 'kornya', 'poluchit', 'dobavit', 'udalit'}
    return bool(set(words) & distinctive) or len(set(words) & russian) >= 2


def school_policy_nodes(tree):
    for node in tree.get('school_external_enums', []):
        yield from school_nodes(node)
    yield from school_nodes(tree)


class SchoolPolicy:
    def __init__(self, source, text, tree, cpp=None):
        self.source, self.text, self.tree = source, text, tree
        self.data = text.encode('utf-8')
        self.cpp = source.suffix not in ('.c', '.h') if cpp is None else cpp
        self.code = school_mask(text)
        self.findings = []
        self.reviews = {}
        self.justifications = {}
        self.error_justifications = {}
        self.accepted = set()
        self.constants = dict(tree.get('school_external_values', {}))
        self.labels = {}
        self.functions = []
        self.symbols = {node['id']: node for node in school_nodes(tree)
                        if 'id' in node and node.get('kind', '').endswith('Decl')}
        self.record_bases = {**tree.get('school_external_bases', {}), **{
            node.get('name'): [base.get('type', {}).get('desugaredQualType', base.get('type', {}).get('qualType', ''))
                               for base in node.get('bases', [])]
            for node in school_nodes(tree) if node.get('kind') == 'CXXRecordDecl'
            and node.get('completeDefinition')}}
        for node in school_policy_nodes(tree):
            if node.get('kind') == 'EnumDecl':
                value = -1
                for member in node.get('inner', []):
                    if member.get('kind') == 'EnumConstantDecl':
                        explicit = next(iter(member.get('inner', [])), None)
                        current = school_integer(explicit, self.constants)
                        value = value + 1 if current is None else current
                        self.constants[member.get('id')] = value
            if self.local(node) and node.get('kind') == 'LabelStmt':
                self.labels[node.get('declId')] = self.offset(node)
            if self.local(node) and node.get('kind') == 'FunctionDecl':
                if any(child.get('kind') == 'CompoundStmt' for child in node.get('inner', [])):
                    self.functions.append(node)
        self.has_main = any(node.get('name') == 'main' for node in self.functions)
        self.resource_ids = set()
        acquisitions = SCHOOL_ALLOCATORS | {'fopen', 'fdopen', 'freopen', 'open', 'socket', 'opendir', 'dup', 'popen'}
        releases = {'free', 'fclose', 'close', 'closedir', 'pclose'}
        for node in school_nodes(tree):
            kind, children = node.get('kind'), node.get('inner', [])
            if kind == 'VarDecl' and any(
                    child.get('kind') == 'CXXNewExpr' or
                    child.get('kind') == 'CallExpr' and self.callee(child) in acquisitions
                    for child in school_nodes(node)):
                self.resource_ids.add(node.get('id'))
            if kind == 'BinaryOperator' and node.get('opcode') == '=' and len(children) == 2:
                if any(child.get('kind') == 'CallExpr' and self.callee(child) in acquisitions
                       for child in school_nodes(children[1])):
                    self.resource_ids.add(school_unwrap(children[0]).get('referencedDecl', {}).get('id'))
            if kind == 'CallExpr' and self.callee(node) in releases and len(children) > 1:
                self.resource_ids.add(school_unwrap(children[1]).get('referencedDecl', {}).get('id'))
        self.read_reviews()

    def offset(self, node):
        return school_location(node).get('offset', 0)

    def local(self, node):
        if node.get('isImplicit'):
            return False
        loc = school_location(node)
        return ('offset' in loc and 'includedFrom' not in loc and
                loc.get('file', '<stdin>') == '<stdin>' and
                0 <= loc['offset'] < len(self.data))

    def excerpt(self, node):
        span = node.get('range', {})
        start, end = span.get('begin', {}), span.get('end', {})
        start, end = start.get('expansionLoc', start), end.get('expansionLoc', end)
        if 'offset' not in start or 'offset' not in end:
            return ''
        return self.data[start['offset']:end['offset'] + end.get('tokLen', 1)].decode('utf-8')

    def emit(self, rule, message, node=None, line=None, review=False, source=None):
        if rule not in SCHOOL_RULES:
            raise ValueError('unregistered school rule: ' + rule)
        if line is None:
            line = self.data[:self.offset(node or {})].count(b'\n') + 1
        if not review and (rule, line) in self.error_justifications:
            self.accepted.add(rule)
            return
        if review:
            if rule not in SCHOOL_WARNING_RULES or rule == '4.4.4' and self.cpp:
                return
            if rule in self.reviews or (rule, line) in self.justifications:
                self.accepted.add(rule)
                return
        offset = self.offset(node or {})
        start = self.data.rfind(b'\n', 0, offset) + 1
        column = len(self.data[start:offset].decode('utf-8', errors='replace')) + 1 if node else 1
        self.findings.append(FormatFinding(source or self.source, line, column, rule,
                             'warning' if review else 'error', message))

    def callee_declaration(self, node):
        children = node.get('inner', [])
        if not children:
            return {}
        target = school_unwrap(children[0])
        seen = set()
        while True:
            if target.get('kind') == 'UnaryOperator' and target.get('opcode') in ('*', '&'):
                target = school_unwrap(target['inner'][0])
            reference = target.get('referencedDecl', {})
            if reference.get('kind') in ('FunctionDecl', 'CXXMethodDecl'):
                return reference
            identifier = reference.get('id')
            if not identifier or identifier in seen:
                return {}
            seen.add(identifier)
            declaration = self.symbols.get(identifier, {})
            values = declaration.get('inner', [])
            if declaration.get('kind') != 'VarDecl' or not values:
                return {}
            target = school_unwrap(values[-1])

    def callee(self, node):
        name = self.callee_declaration(node).get('name', '').removeprefix('__builtin_')
        fortified = name.removeprefix('__').removesuffix('_chk')
        return fortified if name.endswith('_chk') and fortified in SCHOOL_UNSAFE_CALLS else name

    def canonical_declaration(self, identifier):
        seen = set()
        while identifier not in seen:
            seen.add(identifier)
            previous = self.symbols.get(identifier, {}).get('previousDecl')
            if not previous:
                break
            identifier = previous
        return identifier

    def read_reviews(self):
        for token, marker, associated in format_annotations(self.text):
            if marker[2] not in SCHOOL_RULES:
                self.findings.append(FormatFinding(self.source, self.text[:token.start()].count('\n') + 1,
                                     1, 'review-comment', 'error', 'unknown annotated rule'))
                continue
            if marker[1] == 'school-error-justified':
                self.error_justifications[marker[2], associated] = marker[3] or ''
            elif marker[1] == 'school-justified':
                self.justifications[marker[2], associated] = marker[3] or ''
        for token in SCHOOL_LEXER.finditer(self.text):
            if not token.group('comment'):
                continue
            line_number = self.text[:token.start()].count('\n') + 1
            for index, raw_line in enumerate(token[0].splitlines()):
                line = re.sub(r'^\s*(?://|/\*|\*)?\s*', '', raw_line).removesuffix('*/').strip()
                if not line.startswith('school-reviewed'):
                    continue
                match = re.fullmatch(r'school-reviewed\s+([0-9., ]+):\s*(.+)', line)
                problem = None
                if match is None:
                    problem = 'expected school-reviewed RULE[, RULE]: a specific rationale'
                elif len(match[2].strip()) < 12:
                    problem = 'provide a specific rationale of at least 12 characters'
                if problem:
                    self.findings.append(FormatFinding(self.source, line_number + index, 1,
                                         'review-comment', 'error', problem))
                    continue
                for rule in (value.strip() for value in match[1].split(',')):
                    if rule not in SCHOOL_RULES:
                        problem = 'unknown rule ' + rule
                    elif rule not in SCHOOL_REVIEW_RULES:
                        problem = 'cannot waive mechanical rule ' + rule
                    else:
                        self.reviews[rule] = match[2].strip()
                        continue
                    self.findings.append(FormatFinding(self.source, line_number + index, 1,
                                         'review-comment', 'error', problem))

    def declarations(self, node, ancestors):
        kind, name = node.get('kind'), node.get('name', '')
        typ = node.get('type', {}).get('desugaredQualType',
                                     node.get('type', {}).get('qualType', ''))
        declaration = kind in ('FunctionDecl', 'CXXMethodDecl', 'VarDecl', 'FieldDecl',
                               'ParmVarDecl', 'EnumConstantDecl', 'TypedefDecl',
                               'RecordDecl', 'CXXRecordDecl', 'EnumDecl', 'LabelStmt')
        if kind == 'CXXMethodDecl' and name.startswith('operator'):
            declaration = False  # Operator spellings are imposed by the language.
        if declaration and name and name not in ('main', 'argc', 'argv'):
            if not name.isascii():
                self.emit('3.2', 'use ASCII identifier spelling.', node)
            elif school_transliteration(name):
                self.emit('3.2', 'replace the high-confidence transliterated identifier: ' + name, node)
        if kind in ('FunctionDecl', 'CXXMethodDecl', 'VarDecl') and name and name != 'main':
            global_decl = kind != 'VarDecl' or not any(
                p.get('kind') in ('FunctionDecl', 'CXXMethodDecl', 'LambdaExpr') for p in ancestors)
            if global_decl and len(name.strip('_')) < 3:
                self.emit('3.1', 'use at least three characters for a function/global name: ' + name, node)
        constant = kind == 'EnumConstantDecl' or kind == 'VarDecl' and 'const' in typ and '*' not in typ
        if declaration and name:
            if constant:
                if not re.fullmatch(r'[A-Z][A-Z0-9_]*', name):
                    self.emit('3.3', 'use UPPER_SNAKE_CASE for constant ' + name, node)
            elif kind in ('RecordDecl', 'CXXRecordDecl', 'TypedefDecl', 'EnumDecl'):
                if not re.fullmatch(r'[A-Z][A-Za-z0-9]*', name):
                    self.emit('3.6', 'use PascalCase for type/tag ' + name, node)
            elif not re.fullmatch(r'[a-z][a-z0-9_]*', name):
                teacher_exception = kind in ('FunctionDecl', 'CXXMethodDecl')
                self.emit('3.4', 'use lower_snake_case for {}; a function exception needs teacher approval.'.format(name),
                          node, review=teacher_exception)
            if name in ('l', 'I', 'O'):
                self.emit('3.7', 'rename visually ambiguous identifier ' + name, node)
            elif re.search(r'[IlO0]{2,}', name):
                self.emit('3.7', 'verify visual readability of ' + name, node, review=True)
        if kind in ('VarDecl', 'ParmVarDecl', 'FieldDecl') and name not in ('argc', 'argv') and name:
            prefix = re.match(r'^(p|ptr|i|int|str|dbl|double)_', name)
            matches_type = prefix and (
                prefix[1] in ('p', 'ptr') and '*' in typ or
                prefix[1] in ('i', 'int') and re.search(r'\bint\b', typ) or
                prefix[1] == 'str' and 'char' in typ and '*' in typ or
                prefix[1] in ('dbl', 'double') and 'double' in typ)
            if matches_type:
                self.emit('3.5', 'identifier prefix matches its declared type: ' + name, node, review=True)
        if kind == 'FieldDecl' and name and self.cpp and (name.startswith('m_') or name.endswith('_')):
            self.emit('4.1', 'remove the m_ prefix or trailing underscore from this class field.', node)
        if kind == 'VarDecl':
            local = any(p.get('kind') in ('FunctionDecl', 'CXXMethodDecl', 'LambdaExpr') for p in ancestors)
            if constant and re.search(r'\b(char|short|int|long|bool)\b', typ) and school_integer(next(reversed(node.get('inner', [])), {}), self.constants) not in (-1, 2):
                self.emit('5.2', 'define integer constants with enum, not const.', node)
            if not local and node.get('storageClass') != 'extern' and not constant:
                self.emit('5.14', 'mutable global state: consider passing this value as a parameter.', node, review=True)
            if local and '[' in typ and not re.search(r'\(\s*\*[^)]*\)\s*\[', typ):
                dimensions = re.findall(r'\[([^]]*)\]', typ)
                if any(not dimension.isdecimal() for dimension in dimensions):
                    self.emit('5.16', 'replace this variable-length array with fixed-size storage or allocation.', node)
            init = node.get('inner', [])
            if local and typ.startswith(('struct ', 'union ')) and '*' not in typ and '[' not in typ:
                if init:
                    self.emit('4.4.4', 'zero the local structure with memset before assigning fields.', node,
                              review=self.cpp)
                else:
                    self.structure_zeroing(node, ancestors)
            resource_calls = {self.callee(n) for n in school_nodes(node)
                              if n.get('kind') == 'CallExpr'} & (
                                  SCHOOL_ALLOCATORS | {'fopen', 'fdopen', 'open', 'socket', 'opendir', 'dup'})
            owned = node.get('id') in self.resource_ids or resource_calls or re.search(r'\b(?:FILE|DIR)\s*\*', typ)
            if local and owned:
                body = next((n for n in reversed(ancestors) if n.get('kind') == 'CompoundStmt'), None)
                function_body = next((n for n in ancestors if n.get('kind') == 'CompoundStmt'), None)
                if body is not function_body:
                    self.emit('5.17', 'move resource-holding declarations to the beginning of the function.', node)
                elif body:
                    declaration = next((p for p in reversed(ancestors) if p.get('kind') == 'DeclStmt'), None)
                    statements = body.get('inner', [])
                    if declaration in statements:
                        before = statements[:statements.index(declaration)]
                        if any(n.get('kind') != 'DeclStmt' for n in before):
                            self.emit('5.17', 'declare this resource before executable statements.', node)
                if not node.get('init'):
                    self.emit('5.17', 'initialize the resource to a valid handle or its unallocated sentinel.', node)
                self.emit('5.17', 'prove ownership/borrowing, initialization and timely cleanup on every exit.', node,
                          review=True)
            elif local and ('*' in typ or any(child.get('kind') == 'CXXConstructExpr' for child in init)):
                self.emit('5.17', 'verify this borrowed pointer/custom object lifetime and any RAII cleanup.', node,
                          review=True)

    def structure_zeroing(self, node, ancestors):
        """Require the first real use to zero the whole object, without inventing a memset."""
        function = next((parent for parent in reversed(ancestors)
                         if parent.get('kind') in ('FunctionDecl', 'CXXMethodDecl')), {})
        identifier = node.get('id')

        def first_use(current, parents=()):
            if current.get('kind') == 'DeclRefExpr' and current.get('referencedDecl', {}).get('id') == identifier:
                return parents
            for child in current.get('inner', []):
                result = first_use(child, (*parents, current))
                if result is not None:
                    return result
            return None

        parents = first_use(function)
        if parents is None:
            return  # No initialization is needed for an object which is never used.
        call = next((parent for parent in reversed(parents) if parent.get('kind') == 'CallExpr'), {})
        arguments = call.get('inner', [])[1:]
        zeroed = self.callee(call) in ('memset', '__memset_chk') and len(arguments) >= 3
        if zeroed:
            address, count = school_unwrap(arguments[0]), school_unwrap(arguments[2])
            zeroed = (address.get('kind') == 'UnaryOperator' and address.get('opcode') == '&' and
                      any(child.get('referencedDecl', {}).get('id') == identifier for child in school_nodes(address)) and
                      school_integer(arguments[1], self.constants) == 0 and count.get('name') == 'sizeof' and
                      any(child.get('referencedDecl', {}).get('id') == identifier for child in school_nodes(count)))
        if not zeroed:
            self.emit('4.4.4', 'memset the entire local structure to zero before its first use/field assignment.',
                      node, review=self.cpp)
        elif any(parent.get('kind') in ('IfStmt', 'ForStmt', 'WhileStmt', 'SwitchStmt') for parent in parents):
            self.emit('4.4.4', 'verify every path zeroes this structure before any field is used.', node, review=True)

    def functions_and_records(self, node, ancestors):
        kind = node.get('kind')
        children = node.get('inner', [])
        if kind in ('FunctionDecl', 'CXXMethodDecl'):
            body = next((child for child in children if child.get('kind') == 'CompoundStmt'), None)
            if body is not None:
                parameters = school_definition_parameters(self.text, node)
                if parameters and parameters[1] == parameters[0] + 1:
                    self.emit('4.5.2', 'write (void) for a definition with no parameters; resolve incompatible calls first.', node)
                if parameters:
                    start = node.get('loc', {}).get('offset')
                    finish = body.get('range', {}).get('begin', {}).get('offset')
                    if start is not None and finish is not None:
                        line_start = self.data.rfind(b'\n', 0, start) + 1
                        header = self.data[line_start:finish].decode('utf-8')
                        base = len(header) - len(header.lstrip(' '))
                        if base + len(' '.join(header.split())) + 2 > 70:
                            brace_line = self.data[self.data.rfind(b'\n', 0, finish) + 1:finish]
                            correct = not brace_line.strip()
                            for parameter in (child for child in children if child.get('kind') == 'ParmVarDecl'):
                                location = parameter.get('range', {}).get('begin', {}).get('offset')
                                if location is None:
                                    correct = False
                                    continue
                                prefix = self.data[self.data.rfind(b'\n', 0, location) + 1:location]
                                correct = correct and prefix == b' ' * (base + 8)
                            if not correct:
                                self.emit('4.5.3', 'put each parameter on its own line at +8 spaces and the opening brace on its own line.', node)
                returns = [n for n in school_nodes(body) if n.get('kind') == 'ReturnStmt']
                if not returns:
                    self.emit('4.5.1', 'add an explicit return, including in void functions.', node)
                if node.get('name') == 'main':
                    if not school_guaranteed_return(body):
                        self.emit('5.7', 'show that every reachable main exit executes an explicit return.',
                                  node, review=True)
                    for ret in returns:
                        value = school_integer(next(iter(ret.get('inner', [])), None), self.constants)
                        if value is None:
                            self.emit('5.7', 'prove this main return value belongs to [0, 128).', ret, review=True)
                        elif not 0 <= value < 128:
                            self.emit('5.7', 'main must return a value in [0, 128).', ret)
        for index, body in enumerate(school_control_bodies(node)):
            chained_else = kind == 'IfStmt' and node.get('hasElse') and index == 1 and body.get('kind') == 'IfStmt'
            if body.get('kind') != 'CompoundStmt' and not chained_else:
                self.emit('4.6.8', 'put this control body inside braces, including an empty body.', body)
        if kind in ('RecordDecl', 'CXXRecordDecl') and node.get('tagUsed') in ('struct', 'union'):
            field_lines = set()
            for field in children:
                if field.get('kind') == 'FieldDecl' and self.local(field):
                    line = self.data[:self.offset(field)].count(b'\n')
                    if line in field_lines:
                        self.emit('4.1', 'declare every structure field on its own line.', field)
                    field_lines.add(line)
        if kind == 'DeclStmt':
            declarations = [n for n in children if n.get('kind') == 'VarDecl']
            if len(declarations) > 1:
                complex_init = any(n.get('init') and not school_simple_initializer(n)
                                   for n in declarations)
                if complex_init:
                    self.emit('4.4.5', 'put each nonconstant initialized variable in its own declaration.', node)
            record_starts = {n.get('range', {}).get('begin', {}).get('offset') for n in children
                             if n.get('kind') in ('RecordDecl', 'CXXRecordDecl')}
            if any(n.get('kind') == 'VarDecl' and n.get('range', {}).get('begin', {}).get('offset')
                   in record_starts for n in children):
                self.emit('4.1', 'separate the record definition from object declarations.', node)
        if kind == 'VarDecl':
            begin = node.get('range', {}).get('begin', {}).get('offset')
            for record in self.tree.get('inner', []):
                if record.get('kind') in ('RecordDecl', 'CXXRecordDecl') and record.get('completeDefinition'):
                    if begin == record.get('range', {}).get('begin', {}).get('offset'):
                        self.emit('4.1', 'separate the record definition from object declarations.', node)
                        break
        if kind == 'InitListExpr':
            typ = node.get('type', {}).get('qualType', '')
            for child in children:
                if child.get('kind') == 'InitListExpr' and self.local(child):
                    if not self.excerpt(child).lstrip().startswith('{'):
                        self.emit('4.4.1', 'write explicit braces around each nested initializer.', child)
            if '[' in typ or typ.startswith(('struct ', 'union ')):
                self.emit('4.4.1', 'confirm the grouping reflects the structure of the initialized data.', node,
                          review=True)
        if kind == 'IndirectGotoStmt':
            self.emit('4.6.11', 'resolve every computed goto target and prove forward cleanup-only control flow.', node, review=True)
        if kind == 'GotoStmt':
            target = self.labels.get(node.get('targetLabelDeclId'))
            if target is not None and target <= self.offset(node):
                self.emit('4.6.11', 'backward goto is prohibited; use a loop.', node)
            else:
                self.emit('4.6.11', 'justify a forward goto for cleanup or exiting nested loops.', node, review=True)
        if kind == 'CXXTryStmt':
            catches = [n for n in children if n.get('kind') == 'CXXCatchStmt']
            for catch in catches:
                parameter = next((n for n in catch.get('inner', []) if n.get('kind') == 'VarDecl'), None)
                if parameter:
                    typ = parameter.get('type', {}).get('qualType', '')
                    builtin = re.fullmatch(r'(?:const )?(?:int|char|double|float|long|short|bool)(?:[ &*]+)?', typ)
                    if not builtin and not ('const ' in typ and '&' in typ):
                        self.emit('4.6.12', 'catch user-defined exception objects by const reference.', parameter)
            previous = []
            for catch in catches:
                parameter = next((n for n in catch.get('inner', []) if n.get('kind') == 'VarDecl'), None)
                if parameter is None:
                    previous.append('*')
                    continue
                typ = parameter.get('type', {}).get('desugaredQualType',
                        parameter.get('type', {}).get('qualType', ''))
                name = re.sub(r'\bconst\b|[&* ]', '', typ)
                bases, pending = set(), list(self.record_bases.get(name, []))
                while pending:
                    base = pending.pop()
                    if base not in bases:
                        bases.add(base)
                        pending.extend(self.record_bases.get(base, []))
                if '*' in previous or name in previous or bases.intersection(previous):
                    self.emit('4.6.12', 'put this specialized catch before handlers for its base types/catch-all.', catch)
                previous.append(name)
            if len(catches) > 1:
                self.emit('4.6.12', 'verify catch order from specialized to general exception types.', node, review=True)

    def expressions(self, node, ancestors):
        kind = node.get('kind')
        inner = node.get('inner', [])
        if kind in ('IntegerLiteral', 'FloatingLiteral'):
            spelling = node.get('range', {}).get('begin', {}).get('spellingLoc', {})
            if spelling.get('file') == '<scratch space>':
                self.emit('4.5.1', 'verify location-sensitive macro values after layout changes (for example __LINE__).',
                          node, review=True)
                return
            generated_in_header = bool(spelling.get('includedFrom'))
            constant_context = generated_in_header or any(n.get('kind') == 'EnumConstantDecl' or
                n.get('kind') == 'VarDecl' and 'const' in n.get('type', {}).get('qualType', '') and
                '*' not in n.get('type', {}).get('qualType', '') for n in ancestors)
            if not constant_context and str(node.get('value')) not in ('0', '1', '2'):
                stderr_descriptor = False
                for parent in reversed(ancestors):
                    if parent.get('kind') == 'CallExpr':
                        name = self.callee(parent)
                        args = parent.get('inner', [])[1:]
                        descriptor_index = {'write': 0, 'dprintf': 0, 'dup2': 1}.get(name)
                        if descriptor_index is not None and len(args) > descriptor_index:
                            stderr_descriptor = (school_unwrap(args[descriptor_index]) is node and
                                                 node.get('value') == '2')
                        break
                if not stderr_descriptor:
                    self.emit('5.1', 'replace literal {} with a named constant.'.format(node.get('value')), node)
        if kind == 'UnaryOperator' and node.get('opcode') == '-' and inner and school_integer(inner[0], self.constants) == 1:
            if not any(parent.get('kind') == 'EnumConstantDecl' for parent in ancestors):
                self.emit('5.1', 'confirm -1 is an error sentinel; otherwise use a named constant.', node, review=True)
        if kind == 'EnumConstantDecl':
            self.emit('5.2', 'enum name spells a number rather than its use: ' + node.get('name', ''),
                      node, review=True)
        if kind == 'UnaryOperator' and node.get('opcode') == '*' and inner:
            base = school_unwrap(inner[0])
            if base.get('kind') == 'BinaryOperator' and base.get('opcode') == '+':
                self.emit('4.7.8', 'replace *(pointer + index) with pointer[index].', node)
        if kind == 'MemberExpr' and not node.get('isArrow') and inner:
            base = school_unwrap(inner[0])
            if base.get('kind') == 'UnaryOperator' and base.get('opcode') == '*':
                self.emit('4.7.8', 'replace (*pointer).member with pointer->member.', node)
        if kind == 'ParenExpr' and inner:
            child = school_unwrap(inner[0])
            parent = next((p for p in reversed(ancestors) if p.get('kind') != 'ImplicitCastExpr'), {})
            if parent.get('kind') != 'UnaryExprOrTypeTraitExpr':
                simple = child.get('kind') in ('DeclRefExpr', 'IntegerLiteral', 'FloatingLiteral',
                    'ArraySubscriptExpr', 'MemberExpr', 'CallExpr', 'ParenExpr')
                control = parent.get('kind') in ('IfStmt', 'WhileStmt', 'DoStmt', 'SwitchStmt')
                assignment = child.get('kind') == 'BinaryOperator' and child.get('opcode') in ('=', '+=', '-=')
                precedence = {',': 1, '=': 2, '||': 4, '&&': 5, '|': 6, '^': 7, '&': 8,
                              '==': 9, '!=': 9, '<': 10, '<=': 10, '>': 10, '>=': 10,
                              '<<': 11, '>>': 11, '+': 12, '-': 12, '*': 13, '/': 13, '%': 13}
                child_precedence = precedence.get(child.get('opcode'))
                parent_precedence = precedence.get(parent.get('opcode'))
                redundant_binary = (child_precedence is not None and parent_precedence is not None
                                    and child_precedence > parent_precedence)
                root_expression = parent.get('kind') == 'ReturnStmt' and not any(
                    ancestor.get('kind') == 'DecltypeType' for ancestor in ancestors)
                if (simple and parent.get('kind') != 'DecltypeType' or control and not assignment or
                        redundant_binary or root_expression):
                    self.emit('4.7.9', 'remove redundant parentheses around this expression.', node)
                elif assignment or child.get('kind') == 'CXXOperatorCallExpr':
                    self.emit('4.7.9', 'confirm this grouping is needed for an intentional assignment or overloaded operator.',
                              node, review=True)
        if kind == 'UnaryExprOrTypeTraitExpr' and node.get('name') == 'sizeof' and node.get('argType'):
            allocated = any(p.get('kind') == 'CallExpr' and self.callee(p) in SCHOOL_ALLOCATORS
                            for p in ancestors)
            self.emit('5.10', 'use sizeof(object) or sizeof(*pointer) when an object expression is available.',
                      node, review=not allocated)
        if kind == 'CStyleCastExpr' and not self.cpp:
            if any(n.get('kind') == 'CallExpr' and self.callee(n) in SCHOOL_ALLOCATORS
                   for n in school_nodes(node)):
                self.emit('5.18', 'remove the explicit cast of the allocation result.', node)

    def string_literal(self, node):
        node = school_unwrap(node)
        if node.get('kind') != 'StringLiteral':
            return None
        spelling = node.get('value', '')
        spelling = re.sub(r'^(?:u8|[uUL])(?=")', '', spelling)
        try:
            value = school_python_ast.literal_eval(spelling)
        except (ValueError, SyntaxError):
            return None
        return value.split('\0', 1)[0] if isinstance(value, str) else None

    def output_details(self, node):
        name = self.callee(node)
        args = node.get('inner', [])[1:]
        if name not in SCHOOL_OUTPUT_CALLS:
            return None
        if name in ('printf', 'vprintf', 'puts', 'putchar'):
            stream, index = 'stdout', 0
        elif name == 'perror':
            return 'stderr', True, False, None
        elif name in ('fprintf', 'vfprintf', 'dprintf'):
            stream, index = self.excerpt(args[0]) if args else '', 1
            if name == 'dprintf' and args:
                descriptor = school_integer(args[0], self.constants)
                stream = {1: 'stdout', 2: 'stderr'}.get(descriptor, stream)
        elif name in ('fputs', 'fputc', 'putc'):
            stream, index = self.excerpt(args[1]) if len(args) > 1 else '', 0
        else:
            stream, index = self.excerpt(args[0]) if args else '', 1
        if 'stderr' in stream:
            stream = 'stderr'
        elif 'stdout' in stream:
            stream = 'stdout'
        character = name in ('putchar', 'putc', 'fputc')
        value = self.string_literal(args[index]) if len(args) > index else None
        if name == 'puts':
            return stream, True, False, value
        if character:
            number = school_integer(args[index], self.constants) if len(args) > index else None
            return stream, True if number == 10 else None, True, None
        if value is None or name in ('vprintf', 'vfprintf', 'write'):
            return stream, None, False, value
        if not value:
            return stream, True, False, value
        if value.endswith('\n'):
            return stream, True, False, value
        if name in ('printf', 'fprintf', 'dprintf') and re.search(r'%(?:[-+ #0]*\d*(?:\.\d+)?[hljztL]*)?[sc]$', value):
            return stream, None, False, value
        return stream, False, False, value

    def output_completion(self, node, ancestors, details):
        stream, newline, character, _ = details
        if newline or character or newline is None:
            return newline
        if not ancestors or ancestors[-1].get('kind') != 'CompoundStmt':
            return None
        statements = ancestors[-1].get('inner', [])
        if node not in statements:
            return None
        following = statements[statements.index(node) + 1:]
        for statement in following:
            if statement.get('kind') == 'ReturnStmt':
                function = next((p for p in reversed(ancestors)
                                 if p.get('kind') == 'FunctionDecl'), {})
                return False if function.get('name') == 'main' else None
            if statement.get('kind') != 'CallExpr':
                return None
            other = self.output_details(statement)
            if other is None or other[0] != stream:
                return None
            if other[1]:
                return True
            if other[1] is None:
                return None
        return None

    def allocation_owner(self, node, ancestors):
        for parent in reversed(ancestors):
            if parent.get('kind') == 'VarDecl':
                return parent
            if parent.get('kind') == 'BinaryOperator' and parent.get('opcode') == '=':
                lhs = school_unwrap(parent.get('inner', [{}])[0])
                return self.symbols.get(lhs.get('referencedDecl', {}).get('id'), {})
        return {}

    def small_buffer(self, node, ancestors, owner):
        if not owner or '*' not in owner.get('type', {}).get('qualType', ''):
            return
        name = self.callee(node)
        args = node.get('inner', [])[1:]
        base_type = owner.get('type', {}).get('qualType', '').replace('const ', '').replace('*', '').strip()
        if base_type not in ('char', 'signed char', 'unsigned char'):
            self.emit('5.15', 'verify fixed local buffers at most 64 KiB use stack storage when their lifetime permits.',
                      node, review=True)
            return
        if name == 'calloc' and len(args) > 1:
            count = school_integer(args[0], self.constants)
            element = school_unwrap(args[1])
            bytes_known = element.get('kind') == 'UnaryExprOrTypeTraitExpr' and element.get('name') == 'sizeof'
        else:
            count, bytes_known = None, False
        if count is None or not bytes_known or not 0 < count <= 65536:
            self.emit('5.15', 'verify this allocation is variable-sized, larger than 64 KiB, or needs escaping lifetime.',
                      node, review=True)
            return
        function = next((p for p in ancestors if p.get('kind') == 'FunctionDecl'), {})
        identifier = owner.get('id')
        escaping = False
        safe_calls = {'free', 'memset', 'memcpy', 'memmove', 'strlen', 'strcmp', 'printf', 'fprintf', 'scanf', 'fscanf'}
        for use in school_nodes(function):
            references = [n for n in school_nodes(use) if n.get('kind') == 'DeclRefExpr'
                          and n.get('referencedDecl', {}).get('id') == identifier]
            if references and use.get('kind') == 'ReturnStmt' and any('*' in child.get('type', {}).get('qualType', '') for child in use.get('inner', [])):
                escaping = True
            if references and use.get('kind') == 'CallExpr' and use is not node and self.callee(use) not in safe_calls:
                escaping = True
        self.emit('5.15', 'replace this fixed small local char buffer with a stack array.',
                  node, review=escaping)

    def calls(self, node, ancestors):
        if node.get('kind') != 'CallExpr':
            return
        name = self.callee(node)
        args = node.get('inner', [])[1:]
        if name in SCHOOL_UNSAFE_CALLS:
            self.emit('5.8', 'replace unsafe {} with a bounded checked operation.'.format(name), node)
        if not name:
            self.emit('5.8', 'verify this indirect call cannot reach a prohibited unsafe function.', node, review=True)
        if name in ('scanf', 'fscanf', 'sscanf'):
            index = 0 if name == 'scanf' else 1
            fmt = school_unwrap(args[index]) if len(args) > index else {}
            if fmt.get('kind') != 'StringLiteral':
                self.emit('5.8', 'verify every string input conversion has a positive maximum width.', node, review=True)
            else:
                value = fmt.get('value', '').replace('%%', '')
                if re.search(r'%(?:\d+\$)?\*?0*(?:hh|ll|[hljztL])?s', value):
                    self.emit('5.8', 'add a positive width to every scanf %s conversion.', node)
        if name in SCHOOL_OUTPUT_CALLS:
            helper = next((p for p in reversed(ancestors)
                           if p.get('kind') in ('FunctionDecl', 'CXXMethodDecl')), {})
            if helper.get('name') != 'main':
                self.emit('5.13', 'confirm this helper is an output operation, not a general-purpose utility.',
                          node, review=helper.get('name') != 'getline')
            details = self.output_details(node)
            stream = details[0]
            if name != 'perror':
                self.emit('5.4', 'confirm results go to stdout and diagnostics go to stderr.', node, review=True)
            completion = self.output_completion(node, ancestors, details)
            if completion is not True:
                rules = ('5.5',) if stream == 'stderr' else ('5.6',) if stream == 'stdout' else ('5.5', '5.6')
                for rule in rules:
                    self.emit(rule, 'terminate complete messages/results with newline, or justify split/character-stream output.',
                              node, review=completion is None)
        if name == 'malloc':
            owner = self.allocation_owner(node, ancestors)
            owner_type = owner.get('type', {}).get('desugaredQualType', owner.get('type', {}).get('qualType', ''))
            record_name = re.sub(r'\b(?:struct|const)\b|[ *]', '', owner_type)
            record = next((item for item in school_nodes(self.tree)
                           if item.get('kind') in ('RecordDecl', 'CXXRecordDecl') and
                           item.get('name') == record_name and item.get('completeDefinition')), {})
            linked = any(field.get('kind') == 'FieldDecl' and '*' in field.get('type', {}).get('qualType', '') and
                         re.search(r'\b' + re.escape(record_name) + r'\b', field.get('type', {}).get('qualType', ''))
                         for field in record.get('inner', []))
            function = next((parent for parent in ancestors if parent.get('kind') == 'FunctionDecl'), {})
            grown = False
            for call in school_nodes(function):
                arguments = call.get('inner', [])[1:]
                if call.get('kind') == 'CallExpr' and self.callee(call) == 'realloc' and arguments:
                    grown = any(child.get('referencedDecl', {}).get('id') == owner.get('id')
                                for child in school_nodes(arguments[0]))
                    if grown:
                        break
            if linked or not grown:
                self.emit('5.9', 'use calloc for list/tree nodes; no matching realloc was found for this allocation.',
                          node, review=not linked)
        if name in SCHOOL_ALLOCATORS:
            size_index = 1 if name in ('calloc', 'realloc') else 0
            size = school_unwrap(args[size_index]) if len(args) > size_index else {}
            size_nodes = list(school_nodes(size))
            has_sizeof = any(n.get('kind') == 'UnaryExprOrTypeTraitExpr' and n.get('name') == 'sizeof'
                             for n in size_nodes)
            product = size.get('kind') == 'BinaryOperator' and size.get('opcode') == '*'
            if not has_sizeof or name != 'calloc' and not product:
                self.emit('5.11', 'calculate bytes as count * sizeof(element), including char arrays.', node)
            else:
                self.emit('5.11', 'verify the count and sizeof expression describe the same allocated element type.',
                          node, review=True)
            if name in ('malloc', 'calloc'):
                owner = self.allocation_owner(node, ancestors)
                self.small_buffer(node, ancestors, owner)

    def source_rules(self):
        measured_text = self.text
        for token, _, _ in reversed(list(format_annotations(self.text))):
            measured_text = measured_text[:token.start()] + ''.join(
                '\n' if char == '\n' else ' ' for char in token[0]) + measured_text[token.end():]
        measured_lines = measured_text.split('\n')
        for number, line in enumerate(self.text.split('\n'), 1):
            if any(ord(c) < 32 and c != '\r' or ord(c) == 127 for c in line):
                self.emit('1.2' if '\t' in line else '1.1',
                          'replace control characters/tabs with spaces or escaped literal text.', line=number)
            if len(measured_lines[number - 1].rstrip()) > 100:
                self.emit('2.2', 'split the literal/comment to at most 100 characters.', line=number)
        for match in SCHOOL_LEXER.finditer(self.text):
            comment = match.group('comment')
            if comment and re.search(r'\bclang-format\s+off\b', comment):
                self.emit('2.1', 'remove clang-format off to validate school layout; use --clang for custom formatting.',
                          line=self.text[:match.start()].count('\n') + 1)
            if comment and not re.search(r'school-(?:reviewed|justified|warning)', comment) and re.search(
                    r'(?:\b(?:if|for|while|printf|return)\b.*[;{}]|\w+\s*=[^=].*;)', comment):
                self.emit('5.12', 'remove commented-out debugging code or explain why this is documentation.',
                          line=self.text[:match.start()].count('\n') + 1, review=True)
        for number, line in enumerate(self.code.splitlines(), 1):
            name = re.match(r'\s*#\s*define\s+([A-Za-z_]\w*)', line)
            if name and name[1] in ('I', 'O'):
                self.emit('3.7', 'rename visually ambiguous constant ' + name[1], line=number)
            macro = re.match(r'\s*#\s*define\s+\w+\s+(.+)', line)
            integer_macro = macro and re.search(r'\b(?:0[xX][\da-fA-F]+|\d+)[uUlL]*\b', macro[1]) and not re.search(r'\d\.\d|\d[eEpP][+-]?\d', macro[1])
            exception = macro and re.fullmatch(r'[()\s]*(-\s*1|2)[uUlL]*[()\s]*', macro[1])
            if integer_macro and not exception:
                self.emit('5.2', 'replace integer #define with enum.', line=number)
            if re.match(r'\s*#\s*define\s+\w+\(', line):
                self.emit('4.5.1', 'review function-like macros separately; prefer a typed function.',
                          line=number, review=True)
        SchoolProjectAudit(self).run()

    def run(self):
        self.source_rules()

        def visit(node, ancestors=()):
            if self.local(node):
                self.declarations(node, ancestors)
                self.functions_and_records(node, ancestors)
                self.expressions(node, ancestors)
                self.calls(node, ancestors)
            for child in node.get('inner', []):
                visit(child, (*ancestors, node))
        visit(self.tree)
        return list(dict.fromkeys(self.findings))


def school_constant_expression(node):
    node = school_unwrap(node)
    kind = node.get('kind')
    if kind in ('IntegerLiteral', 'FloatingLiteral', 'CharacterLiteral', 'StringLiteral',
                'CXXBoolLiteralExpr', 'GNUNullExpr', 'CXXNullPtrLiteralExpr'):
        return True
    if kind == 'DeclRefExpr':
        return node.get('referencedDecl', {}).get('kind') == 'EnumConstantDecl'
    if kind == 'UnaryExprOrTypeTraitExpr':
        return not any(n.get('kind') == 'DeclRefExpr' and n.get('referencedDecl', {}).get('kind') != 'EnumConstantDecl'
                       for n in school_nodes(node))
    if kind in ('UnaryOperator', 'BinaryOperator', 'CStyleCastExpr', 'InitListExpr'):
        if node.get('opcode') in ('=', '+=', '-=', '++', '--', ','):
            return False
        return all(school_constant_expression(child) for child in node.get('inner', []))
    return False


def school_simple_initializer(node):
    children = node.get('inner', [])
    return not children or school_constant_expression(children[-1])


def school_guaranteed_return(node):
    kind, inner = node.get('kind'), node.get('inner', [])
    if kind in ('ReturnStmt', 'CXXThrowExpr'):
        return True
    if kind == 'CompoundStmt':
        return bool(inner) and school_guaranteed_return(inner[-1])
    if kind == 'IfStmt' and node.get('hasElse') and len(inner) >= 3:
        return school_guaranteed_return(inner[-1]) and school_guaranteed_return(inner[-2])
    return False


def school_parameter_layout(source, text, tree):
    """Apply PDF 4.5.3 after clang-format, using AST parameter ranges."""
    data = text.encode('utf-8')
    edits = []
    for function in school_nodes(tree):
        if function.get('kind') not in ('FunctionDecl', 'CXXMethodDecl'):
            continue
        body = next((n for n in function.get('inner', []) if n.get('kind') == 'CompoundStmt'), None)
        location = function.get('loc', {})
        if body is None or 'offset' not in location or 'includedFrom' in location:
            continue
        start = location['offset']
        end = body.get('range', {}).get('begin', {}).get('offset')
        if end is None:
            continue
        header = data[start:end].decode('utf-8')
        line_start = data.rfind(b'\n', 0, start) + 1
        prefix = data[line_start:start].decode('utf-8')
        indent = prefix[:len(prefix) - len(prefix.lstrip(' '))]
        logical = ' '.join((prefix + header).split())
        if len(indent) + len(logical) + 2 <= 70:
            continue
        params = [n for n in function.get('inner', []) if n.get('kind') == 'ParmVarDecl']
        name = function.get('name', '')
        parts = []
        for param in params:
            span = param.get('range', {})
            begin, finish = span.get('begin', {}), span.get('end', {})
            if 'offset' not in begin or 'offset' not in finish:
                break
            part = data[begin['offset']:finish['offset'] + finish.get('tokLen', 1)].decode('utf-8')
            # Preserve whitespace inside default string literals and comments.
            if '\n' in part or '\r' in part:
                break  # Keep layout intact; report unsupported parameter wrapping below.
            parts.append(part.strip())
        else:
            if function.get('variadic'):
                parts.append('...')
            if not parts:
                continue
            # Locate the matching closing parenthesis without touching attributes/body.
            parameters = school_definition_parameters(text, function)
            if not parameters:
                continue
            opening = school_tokens(text)[parameters[0]][1] - len(data[:start].decode('utf-8'))
            depth, closing = 0, None
            masked = school_mask(header)
            for index in range(opening, len(masked)):
                if masked[index] == '(':
                    depth += 1
                elif masked[index] == ')':
                    depth -= 1
                    if depth == 0:
                        closing = index
                        break
            if closing is None:
                continue
            suffix = header[closing + 1:].strip()
            replacement = (header[:opening] + '(\n' + ',\n'.join(
                indent + ' ' * 8 + part for part in parts) + ')'
                + (' ' + suffix if suffix else '') + '\n' + indent)
            edits.append((start, end, replacement.encode('utf-8')))
    for start, end, replacement in sorted(edits, reverse=True):
        data = data[:start] + replacement + data[end:]
    return data.decode('utf-8')


def school_label_layout(text, tree):
    data = text.encode('utf-8')
    edits = []

    def visit(node, compounds=()):
        if node.get('kind') == 'CompoundStmt':
            compounds = (*compounds, node)
        if node.get('kind') == 'LabelStmt' and node.get('inner') and compounds:
            child = node['inner'][0]
            start = node.get('range', {}).get('begin', {})
            following = child.get('range', {}).get('begin', {})
            if 'offset' in start and 'offset' in following and 'includedFrom' not in start:
                label_start, child_start = start['offset'], following['offset']
                if data[label_start:child_start].count(b'\n') == 0:
                    body_start = compounds[-1].get('range', {}).get('begin', {}).get('offset', 0)
                    line_start = data.rfind(b'\n', 0, body_start) + 1
                    prefix = data[line_start:body_start].decode('utf-8')
                    base = len(prefix) - len(prefix.lstrip(' '))
                    edits.append((child_start, b'\n' + b' ' * (base + 4)))
        for child in node.get('inner', []):
            visit(child, compounds)
    visit(tree)
    for position, insertion in sorted(set(edits), reverse=True):
        data = data[:position] + insertion + data[position:]
    return data.decode('utf-8')


def school_apply_layout(source, text, clang, tree=None):
    issues = []
    if tree is None:
        tree, issues = school_parse(source, text, clang)
    if issues:
        return text, tree, issues
    candidate = school_parameter_layout(source, text, tree)
    if candidate != text:
        tree, issues = school_parse(source, candidate, clang)
        if issues:
            return candidate, tree, issues
    labeled = school_label_layout(candidate, tree)
    if labeled != candidate:
        tree, issues = school_parse(source, labeled, clang)
    return labeled, tree, issues


def school_needs_resource_analysis(source, text, tree):
    policy = SchoolPolicy(source, text, tree)
    calls = SCHOOL_ALLOCATORS | {'free', 'fopen', 'fdopen', 'freopen', 'fclose', 'open', 'close', 'socket', 'opendir', 'closedir', 'dup', 'popen', 'pclose'}
    for node in school_nodes(tree):
        if not policy.local(node):
            continue
        kind = node.get('kind')
        if kind in ('CXXNewExpr', 'CXXDeleteExpr'):
            return True
        if kind == 'ArraySubscriptExpr':
            base = school_unwrap(next(iter(node.get('inner', [])), {}))
            # Skip only actual array objects, including multidimensional
            # indexing. Calls/references/fields can still hide borrowed storage.
            while base.get('kind') == 'ArraySubscriptExpr':
                base = school_unwrap(next(iter(base.get('inner', [])), {}))
            reference = base.get('referencedDecl', {})
            details = reference.get('type', {})
            typ = details.get('desugaredQualType', details.get('qualType', ''))
            if (base.get('kind') != 'DeclRefExpr' or reference.get('kind') != 'VarDecl'
                    or '[' not in typ or '*' in typ or '&' in typ):
                return True
        if kind == 'UnaryOperator' and node.get('opcode') == '*':
            return True
        if kind == 'MemberExpr' and node.get('isArrow'):
            base = school_unwrap(next(iter(node.get('inner', [])), {}))
            details = node.get('type', {})
            typ = details.get('desugaredQualType', details.get('qualType', ''))
            scalar_words = {'const', 'volatile', 'signed', 'unsigned', 'short', 'long',
                            'int', 'char', 'bool', 'float', 'double', 'wchar_t',
                            'char8_t', 'char16_t', 'char32_t', '__int128', '_Bool'}
            plain_scalar = bool(typ.split()) and set(typ.split()) <= scalar_words
            # Only a plain scalar field through this is harmless by itself.
            # Pointer/container fields, method calls and closures retain analysis.
            if base.get('kind') != 'CXXThisExpr' or not plain_scalar:
                return True
        if kind == 'LambdaExpr' and any(child.get('kind') == 'CXXThisExpr' for child in school_nodes(node)):
            return True
        if kind == 'CallExpr' and policy.callee(node) in calls:
            return True
        if kind == 'ReturnStmt' and any('*' in child.get('type', {}).get('qualType', '') for child in node.get('inner', [])):
            return True
    return False


SCHOOL_ANALYZER_CAPABILITIES = {}


def school_analyzer_checkers(clang):
    """Resolve the same stream analysis under stable and older alpha names."""
    if clang in SCHOOL_ANALYZER_CAPABILITIES:
        return SCHOOL_ANALYZER_CAPABILITIES[clang]
    result = school_tool([clang, '-cc1', '-analyzer-checker-help'], capture_output=True, text=True)
    if result.returncode:
        raise CheckSetupError('school: cannot query Clang analyzer checkers: ' + result.stderr)
    available = set(re.findall(r'^\s+([A-Za-z_][\w.]+)\s', result.stdout, re.M))
    stream = 'unix.Stream'
    if stream not in available:
        alpha = school_tool([clang, '-cc1', '-analyzer-checker-help-alpha'], capture_output=True, text=True)
        if alpha.returncode:
            raise CheckSetupError('school: cannot query Clang stream analysis: ' + alpha.stderr)
        available.update(re.findall(r'^\s+([A-Za-z_][\w.]+)\s', alpha.stdout, re.M))
        stream = 'alpha.unix.Stream'
    required = ('unix.Malloc', stream, 'core.NullDereference', 'core.StackAddressEscape',
                'cplusplus.NewDelete', 'cplusplus.NewDeleteLeaks')
    missing = set(required) - available
    if missing:
        raise CheckSetupError('school: install a Clang analyzer providing: ' + ', '.join(sorted(missing)))
    SCHOOL_ANALYZER_CAPABILITIES[clang] = required
    return required


def school_resource_analysis(source, candidate_path, input_path, clang, include_args=()):
    language = 'c' if source.suffix in ('.c', '.h') else 'c++'
    standard = '-std=gnu99' if language == 'c' else '-std=gnu++17'
    checkers = school_analyzer_checkers(clang)
    with tempfile.TemporaryDirectory(prefix='school-analysis-') as directory:
        result = school_tool(
            [clang, '--analyze', '-x', language, standard,
             *(school_cpp_context() if language == 'c++' else []),
             '-iquote', str(source.parent), *include_args,
             '-Xanalyzer', '-analyzer-checker=' + ','.join(checkers),
             '-Xanalyzer', '-analyzer-output=text',
             str(input_path), '-o', str(Path(directory) / 'analysis.plist')],
            text=True, capture_output=True)
    if result.returncode:
        raise CheckSetupError(str(source) + ': school analyzer failed:\n' + result.stderr)
    pattern = re.compile(r'^(.*?):(\d+):(\d+): warning:\s*(.*?)\s*\[((?:alpha\.)?unix\.(?:Malloc|Stream)|core\.(?:NullDereference|StackAddressEscape)|cplusplus\.NewDelete(?:Leaks)?)\]', re.M)
    findings = []
    for match in pattern.finditer(result.stderr):
        owner = source if Path(match[1]) == Path(candidate_path) else Path(match[1])
        findings.append(FormatFinding(owner, int(match[2]), int(match[3]), '5.17', 'error',
                        match[4] + ' [' + match[5] + ']'))
    return findings


# Source: school_project.py
"""Read-only include ownership, header and Makefile auditing for school rules."""


def school_includes(text):
    visible = SCHOOL_LEXER.sub(
        lambda match: ''.join('\n' if c == '\n' else ' ' for c in match[0])
        if match.group('comment') else match[0], text)
    return list(re.finditer(r'^[^\S\r\n]*#[^\S\r\n]*include[^\S\r\n]*([<"])([^>"\n]+)[>"]', visible, re.M))


def school_declaration_key(node):
    kind = node.get('kind')
    if kind not in ('FunctionDecl', 'VarDecl', 'EnumConstantDecl', 'TypedefDecl',
                    'RecordDecl', 'CXXRecordDecl', 'EnumDecl'):
        return None
    name = node.get('name')
    if not name:
        return None
    signature = node.get('type', {}).get('qualType', '') if kind in ('FunctionDecl', 'VarDecl') else ''
    return kind, name, signature


class SchoolProjectAudit:
    def __init__(self, policy):
        self.policy = policy
        self.clang = shutil.which('clang')
        self.headers = {}
        self.direct = set()
        self.parents = {}
        self.macro_include = False

    def includes(self, owner, text):
        result = []
        for directive in school_includes(text):
            opener, name = directive[1], directive[2]
            line = text[:directive.start()].count('\n') + 1
            local = (owner.source.parent / name).resolve()
            if opener == '<':
                if name not in SCHOOL_STANDARD_HEADERS and local.is_file():
                    owner.emit('5.3', 'use quotes for the project header ' + name, line=line)
                continue
            if local.is_file():
                result.append(local)
            elif name in SCHOOL_STANDARD_HEADERS:
                owner.emit('5.3', 'use #include <{}> for this standard header.'.format(name), line=line)
            else:
                owner.emit('5.3', 'identify the owner of this installed header and verify the include delimiters.',
                           line=line, review=True)
        literal_lines = {text[:item.start()].count('\n') for item in school_includes(text)}
        for number, line in enumerate(school_mask(text).splitlines()):
            if re.match(r'\s*#\s*include\b', line) and number not in literal_lines:
                owner.emit('6.4', 'verify direct ownership for this macro-generated include.',
                           line=number + 1, review=True)
                if owner is self.policy:
                    self.macro_include = True
        return result

    def guard(self, policy):
        lines = [line.strip() for line in policy.code.splitlines() if line.strip()]
        pragma = any(re.fullmatch(r'#\s*pragma\s+once', line) for line in lines)
        guarded = False
        if len(lines) >= 3:
            first = re.fullmatch(r'#\s*ifndef\s+([A-Za-z_]\w*)', lines[0])
            if first and re.fullmatch(r'#\s*define\s+' + first[1], lines[1]):
                depth = 0
                guarded = True
                for index, line in enumerate(lines):
                    if re.match(r'#\s*(?:if|ifdef|ifndef)\b', line):
                        depth += 1
                    elif re.match(r'#\s*endif\b', line):
                        depth -= 1
                    if depth < 0 or depth == 0 and index != len(lines) - 1:
                        guarded = False
                guarded = guarded and depth == 0
        if not (pragma or guarded):
            policy.emit('6.2', 'protect the entire header with matching include guards or #pragma once.')
        for node in policy.functions:
            policy.emit('6.1', 'move C function bodies from the header to the implementation module.',
                        node, review=policy.cpp)

    def header(self, path):
        if path in self.headers:
            return
        if len(self.headers) >= 64:
            self.policy.emit('6.4', 'include graph exceeds 64 project headers; verify a smaller complete module context.',
                             review=True)
            return
        text = self.policy.text if path == self.policy.source else path.read_text(encoding='utf-8')
        tree, issues = school_parse(path, text, self.clang, cpp=self.policy.cpp)
        if issues:
            self.policy.findings.append(FormatFinding(path, 1, 1, 'frontend', 'error', '\n'.join(issues)))
            return
        context = self.policy if path == self.policy.source else SchoolPolicy(path, text, tree, cpp=self.policy.cpp)
        self.headers[path] = context
        self.guard(context)
        dependencies = self.includes(context, text)
        self.parents[path] = dependencies
        for dependency in dependencies:
            self.header(dependency)
        self.minimal_includes(context)
        if context is not self.policy:
            self.policy.findings.extend(context.findings)

    def own_nodes(self, context):
        return [node for node in school_nodes(context.tree) if context.local(node)]

    def public_symbols(self, context):
        return {school_declaration_key(node) for node in self.own_nodes(context)
                if school_declaration_key(node) is not None}

    def ownership(self):
        owners = {}
        for path, header in self.headers.items():
            for key in self.public_symbols(header):
                owners.setdefault(key, set()).add(path)
        for node in self.own_nodes(self.policy):
            if node.get('kind') != 'DeclRefExpr':
                continue
            reference = node.get('referencedDecl', {})
            declaration = self.policy.symbols.get(reference.get('id'), {})
            if self.policy.local(declaration):
                continue
            key = school_declaration_key(reference)
            candidates = owners.get(key, set())
            if len(candidates) == 1:
                owner = next(iter(candidates))
                if owner not in self.direct and owner != self.policy.source:
                    self.policy.emit('6.4', 'directly include "{}"; this entity currently arrives transitively.'.format(owner.name),
                                     node, review=self.macro_include)
            elif len(candidates) > 1:
                self.policy.emit('6.4', 'resolve the owning declaration header for ' + reference.get('name', ''),
                                 node, review=True)
        if any(self.public_symbols(context) for context in self.headers.values()):
            self.policy.emit('6.4', 'confirm all other project consumers include their owning headers directly.',
                             review=True)

    def minimal_includes(self, context):
        directives = school_includes(context.text)
        if not directives:
            return
        # Keep guards, but do not make a deletion claim through other preprocessor branches.
        conditionals = re.findall(r'^\s*#\s*(if|ifdef|ifndef|elif|else)\b', context.code, re.M)
        ordinary_guard_only = len(conditionals) <= 1 and (
            not conditionals or re.match(r'\s*#\s*ifndef\b', context.code))
        own = self.public_symbols(context)
        primitive = {'void', 'char', 'signed', 'unsigned', 'short', 'int', 'long',
                     'float', 'double', 'const', 'volatile', 'restrict', '_Bool'}
        simple_interface = all(
            node.get('kind') in ('FunctionDecl', 'ParmVarDecl') and
            set(re.findall(r'[A-Za-z_]\w*', node.get('type', {}).get('qualType', ''))) <= primitive
            for node in self.own_nodes(context)
            if node.get('kind', '').endswith('Decl') and not node.get('isImplicit'))
        for directive in directives:
            without = context.text[:directive.start()] + ''.join(
                '\n' if c == '\n' else ' ' for c in directive[0]) + context.text[directive.end():]
            tree, issues = school_parse(context.source, without, self.clang, cpp=context.cpp)
            if issues:
                continue  # The header demonstrably needs entities from this include.
            other = SchoolPolicy(context.source, without, tree, cpp=context.cpp)
            equal = self.public_symbols(other) == own
            if equal and simple_interface and ordinary_guard_only:
                context.emit('6.5', 'remove implementation-only include "{}" from this primitive declaration interface.'.format(directive[2]),
                             line=context.text[:directive.start()].count('\n') + 1)
            else:
                context.emit('6.5', 'justify include "{}" for the entities declared by this header.'.format(directive[2]),
                             line=context.text[:directive.start()].count('\n') + 1, review=True)

    def module(self):
        policy = self.policy
        if policy.source.suffix != '.c':
            return
        header = policy.source.with_suffix('.h')
        if not header.is_file():
            if not policy.has_main:
                policy.emit('6.1', 'supply a sibling .h with this module\'s types, constants and prototypes.')
        else:
            if header.resolve() not in self.direct:
                policy.emit('6.3', 'directly include your own module header "{}".'.format(header.name))
            context = self.headers.get(header.resolve())
            if context and not policy.has_main:
                declared = self.public_symbols(context)
                for function in policy.functions:
                    if function.get('storageClass') != 'static' and school_declaration_key(function) not in declared:
                        policy.emit('6.1', 'declare this public function in ' + header.name, function)
        if not policy.has_main or self.direct:
            self.makefile()

    def makefile(self):
        policy = self.policy
        candidates = [policy.source.parent / 'Makefile', policy.source.parent / 'makefile']
        makefile = next((path for path in candidates if path.is_file()), None)
        if makefile is None:
            policy.emit('6.6', 'supply Makefile with all and clean targets.')
            return
        targets, variables = set(), {}
        unresolved = False
        for raw in makefile.read_text().splitlines():
            if not raw or raw[0].isspace() or raw.lstrip().startswith('#'):
                continue
            line = raw.split('#', 1)[0]
            assignment = re.fullmatch(r'([A-Za-z_]\w*)\s*(?::=|=)\s*([A-Za-z0-9_ .-]*)', line)
            if assignment:
                variables[assignment[1]] = assignment[2]
                continue
            if re.match(r'(?:-?include|ifn?def|ifn?eq)\b', line):
                unresolved = True
            target = re.match(r'([^:=]+):(?!=)', line)
            if target:
                value = target[1]
                for name, replacement in variables.items():
                    value = value.replace('$(' + name + ')', replacement).replace('${' + name + '}', replacement)
                if '$' in value:
                    unresolved = True
                else:
                    targets.update(value.split())
        if not {'all', 'clean'} <= targets and not unresolved:
            policy.emit('6.6', 'define both all and clean targets in ' + str(makefile))
        else:
            policy.emit('6.6', 'verify all builds every module and clean removes generated objects/executables only.',
                        review=True)

    def run(self):
        if not self.clang:
            raise CheckSetupError('school project audit requires clang')
        if self.policy.source.suffix in ('.h', '.hpp'):
            self.header(self.policy.source)
            self.direct = set(self.parents.get(self.policy.source, []))
        else:
            self.direct = set(self.includes(self.policy, self.policy.text))
            for path in self.direct:
                self.header(path)
        self.ownership()
        self.module()


# Source: school_safety.py
"""Validate automatic school edits without executing the submitted program."""
import bisect as school_bisect


def school_tokens(text):
    """Return spellings and character offsets, preserving literal contents."""
    result = []
    position = 0

    def plain(start, end):
        pattern = (r"(?:\d|\.\d)(?:[\w.']|(?<=[eEpP])[+-])*|[^\W\d]\w*|"
                   r"%:%:|>>=|<<=|\.\.\.|<=>|->\*|\.\*|::|\+\+|--|<<|>>|<=|>=|==|!=|"
                   r"&&|\|\||\*=|/=|%=|\+=|-=|&=|\^=|\|=|->|##|<:|:>|<%|%>|%:|\S")
        for token in re.finditer(pattern, text[start:end]):
            offset = start + token.start()
            if token[0] == '\\' and text[offset + 1:offset + 2] in ('\r', '\n'):
                continue
            result.append((token[0], offset))

    for literal in SCHOOL_LEXER.finditer(text):
        plain(position, literal.start())
        if not literal.group('comment'):
            spelling = re.sub(r'\\(?:\r\n|\r|\n)', '', literal[0])
            result.append((spelling, literal.start()))
        position = literal.end()
    plain(position, len(text))
    return result


def school_definitions(tree):
    for node in school_nodes(tree):
        if node.get('kind') in ('FunctionDecl', 'CXXMethodDecl', 'CXXConversionDecl'):
            location = node.get('loc', {})
            if ('offset' in location and 'includedFrom' not in location and
                    any(child.get('kind') == 'CompoundStmt' for child in node.get('inner', []))):
                yield node


def school_definition_parameters(text, node, tokens=None):
    tokens = school_tokens(text) if tokens is None else tokens
    location = node.get('loc', {})
    if 'offset' not in location or 'includedFrom' in location:
        return None
    offset = len(text.encode('utf-8')[:location['offset']].decode('utf-8'))
    starts = [position for _, position in tokens]
    index = school_bisect.bisect_left(starts, offset)
    name = [value for value, _ in school_tokens(node.get('name', ''))]
    if [value for value, _ in tokens[index:index + len(name)]] != name:
        return None
    index += len(name)
    if index >= len(tokens) or tokens[index][0] != '(':
        return None
    opening, depth = index, 0
    for closing in range(opening, len(tokens)):
        value = tokens[closing][0]
        if value == '(':
            depth += 1
        elif value == ')':
            depth -= 1
            if depth == 0:
                return opening, closing
    return None


def school_directive_spans(text):
    masked = school_mask(text)
    original_lines = text.splitlines(keepends=True)
    masked_lines = masked.splitlines(keepends=True)
    result = []
    offset, beginning = 0, None
    for original, visible in zip(original_lines, masked_lines):
        if beginning is None and visible.lstrip(' \t').startswith('#'):
            beginning = offset
        offset += len(original)
        if beginning is not None and not original.rstrip('\r\n').endswith('\\'):
            result.append((beginning, offset))
            beginning = None
    if beginning is not None:
        result.append((beginning, len(text)))
    return result


def school_control_bodies(node):
    children = node.get('inner', [])
    kind = node.get('kind')
    if kind == 'IfStmt':
        return children[-2:] if node.get('hasElse') else children[-1:]
    if kind in ('WhileStmt', 'ForStmt', 'CXXForRangeStmt'):
        return children[-1:]
    if kind == 'DoStmt':
        return children[:1]
    return []


def school_empty_body_positions(text, tree):
    positions = set()
    data = text.encode('utf-8')
    for node in school_nodes(tree):
        for body in school_control_bodies(node):
            location = body.get('range', {}).get('begin', {})
            if body.get('kind') == 'NullStmt' and 'offset' in location and 'includedFrom' not in location:
                position = location['offset']
                if data[position:position + 1] == b';':
                    positions.add(len(data[:position].decode('utf-8')))
    return positions


def school_spelling_signature(text, skip_void=(), skip_empty=()):
    directives = school_directive_spans(text)
    result = []
    for spelling, offset in school_tokens(text):
        if offset in skip_void and spelling == 'void':
            continue
        if offset in skip_empty and spelling == ';':
            continue
        if spelling in ('{', '}') and not any(start <= offset < end for start, end in directives):
            continue
        if re.fullmatch(r"[^\w\s\"']+", spelling):
            result.extend(spelling)
        else:
            result.append(spelling)
    return result


def school_inserted_void_positions(original, original_tree, candidate, candidate_tree):
    original_tokens, candidate_tokens = school_tokens(original), school_tokens(candidate)
    old_definitions = list(school_definitions(original_tree))
    new_definitions = list(school_definitions(candidate_tree))
    if len(old_definitions) != len(new_definitions):
        return set(), set()
    positions, names = set(), set()
    for old, new in zip(old_definitions, new_definitions):
        old_parameters = school_definition_parameters(original, old, original_tokens)
        new_parameters = school_definition_parameters(candidate, new, candidate_tokens)
        if old.get('name') != new.get('name') or not old_parameters or not new_parameters:
            continue
        old_start, old_end = old_parameters
        new_start, new_end = new_parameters
        if old_end == old_start + 1 and new_end == new_start + 2:
            spelling, position = candidate_tokens[new_start + 1]
            if spelling == 'void':
                positions.add(position)
                names.add(old.get('name'))
    return positions, names


def school_ast_signature(text, tree, void_names=()):
    data = text.encode('utf-8')

    def local(node):
        location = school_location(node)
        return ('offset' in location and 'includedFrom' not in location and
                location.get('file', '<stdin>') == '<stdin>' and
                0 <= location['offset'] < len(data) and not node.get('isImplicit'))

    declarations, labels = {}, {}
    for node in school_nodes(tree):
        if local(node) and node.get('kind', '').endswith('Decl') and 'id' in node:
            declarations.setdefault(node['id'], len(declarations))
        if local(node) and node.get('kind') == 'LabelStmt':
            labels.setdefault(node.get('declId'), len(labels))

    # Clang embeds source coordinates in closure type spellings, including
    # instantiated library function signatures. Assign each closure a stable
    # ordinal; two distinct lambdas must remain two distinct types.
    closure_pattern = re.compile(r'\(lambda at <stdin>:\d+:\d+\)')
    closure_types = {}
    for node in school_nodes(tree):
        if node.get('kind') == 'LambdaExpr':
            for match in closure_pattern.finditer(node.get('type', {}).get('qualType', '')):
                closure_types.setdefault(match[0], len(closure_types))

    def stable_type(value):
        if not value:
            return value
        return closure_pattern.sub(
            lambda match: '<source-lambda-{}>'.format(closure_types[match[0]])
            if match[0] in closure_types else match[0], value)

    properties = ('name', 'opcode', 'value', 'isPostfix', 'isArrow', 'castKind',
                  'storageClass', 'tagUsed', 'variadic', 'hasElse', 'init', 'valueCategory')
    wrappers = {'ImplicitCastExpr', 'ParenExpr', 'ConstantExpr', 'ExprWithCleanups',
                'MaterializeTemporaryExpr'}
    controls = {'IfStmt', 'ForStmt', 'WhileStmt', 'DoStmt', 'CXXForRangeStmt'}

    def signature(node, parent=''):
        kind = node.get('kind')
        if kind in wrappers and len(node.get('inner', [])) == 1:
            return signature(node['inner'][0], parent)
        children = tuple(value for child in node.get('inner', [])
                         if (value := signature(child, kind)) is not None)
        if not local(node):
            return ('source-context', children) if children else None
        if kind == 'CompoundStmt' and parent in controls:
            if len(children) == 1:
                return children[0]
            if not children:
                return ('NullStmt', (), ())
        values = [(key, str(node[key])) for key in properties if key in node]
        typ = node.get('type', {}).get('qualType')
        reference = node.get('referencedDecl', {})
        name = node.get('name') or reference.get('name')
        if typ:
            if name in void_names and (kind in ('FunctionDecl', 'CXXMethodDecl', 'CXXConversionDecl')
                                       or reference.get('kind') == 'FunctionDecl'):
                typ = typ.replace('()', '(void)', 1)
            values.append(('type', stable_type(typ)))
        if reference:
            target = declarations.get(reference.get('id'))
            values.append(('reference', target if target is not None else
                           (reference.get('kind'), reference.get('name'),
                            stable_type(reference.get('type', {}).get('qualType')))))
        if kind == 'GotoStmt':
            values.append(('target', labels.get(node.get('targetLabelDeclId'))))
        # Formatting naturally updates __LINE__ values. Preserve its invocation
        # spelling and require an explicit policy review of location-sensitive code.
        begin = node.get('range', {}).get('begin', {})
        spelling = begin.get('spellingLoc', {})
        expansion = begin.get('expansionLoc', {})
        if kind == 'IntegerLiteral' and spelling.get('file') == '<scratch space>' and 'offset' in expansion:
            line = expansion.get('presumedLine', data[:expansion['offset']].count(b'\n') + 1)
            if str(node.get('value')) == str(line):
                values = [(key, '<source-line>' if key == 'value' else value) for key, value in values]
        return kind, tuple(values), children
    return signature(tree)


def school_verify_layout(source, original, original_tree, candidate, candidate_tree):
    positions, names = school_inserted_void_positions(original, original_tree, candidate, candidate_tree)
    before = school_spelling_signature(original, skip_empty=school_empty_body_positions(original, original_tree))
    after = school_spelling_signature(candidate, positions, school_empty_body_positions(candidate, candidate_tree))
    if before != after:
        raise CheckSetupError(str(source) + ': school: formatter changed non-layout tokens; rewrite the affected macro/literal explicitly, then retry.')
    if school_ast_signature(original, original_tree, names) != school_ast_signature(candidate, candidate_tree, names):
        raise CheckSetupError(str(source) + ': school: formatting changed the parsed program; rewrite the affected construct explicitly, then retry.')


def school_compact_diagnostics(findings):
    """Keep automatic errors intact; show a concise file/rule review list."""
    output, reviews = [], {}
    pattern = re.compile(r'^(.*):(\d+):(\d+): school ([0-9.]+) review required: (.*)$', re.S)
    for finding in findings:
        match = pattern.match(finding)
        if not match:
            output.append(finding)
            continue
        key = (match[1], match[4])
        reviews.setdefault(key, []).append(finding)
    for items in reviews.values():
        output.extend(items[:2])
        if len(items) > 2:
            output.append('  ... {} further locations under the same whole-file review obligation'.format(len(items) - 2))
    return output


# Source: integrations.py
"""Optional formatting and feature-oriented dependency diagnostics."""


def execute_format(config):
    if config.get("format_mode") == "school":
        return execute_school_format(config)
    if config.get("review") or config.get("review_report"):
        return execute_format_review(config)
    sources = config.get("protected", [])
    if not sources:
        raise CheckUsageError("formatting needs a source file")
    jobs = []
    seen = set()
    for source in sources:
        source = str(Path(source).resolve())
        if source in seen:
            continue
        seen.add(source)
        if not Path(source).is_file():
            raise CheckSetupError("source not found: " + source)
        python_source = source.endswith(".py")
        tool = (
            config.get("python_formatter", "ruff")
            if python_source
            else config.get("native_formatter", "clang-format")
        )
        executable = shutil.which(tool)
        if not executable:
            raise CheckSetupError(
                "optional formatter not found: " + tool + "; see https://github.com/V1b3-C0d3r/cp-run/blob/main/docs/CLI.md#formatting"
            )
        check = config.get("prettier") == "check"
        if python_source:
            argv = [
                executable,
                *([] if Path(tool).name.startswith("black") else ["format"]),
                *(["--check"] if check else []),
                source,
            ]
        else:
            argv = [
                executable,
                "--style=file",
                "--fallback-style=LLVM",
                "--sort-includes=false",
                *(["--dry-run", "--Werror"] if check else ["-i"]),
                source,
            ]
        jobs.append(argv)
    # Resolve every dependency before the first edit; no recursive directory sweep.
    for argv in jobs:
        result = subprocess.run(argv, stdout=sys.stderr)
        if result.returncode:
            return result.returncode
    return 0


def execute_doctor(config):
    required = ("zsh", "python3")
    optional = (
        "gcc",
        "g++",
        "clang",
        "clang++",
        config.get("interpreter", "python3"),
        "pypy3",
        config.get("native_formatter", "clang-format"),
        config.get("python_formatter", "ruff"),
        "clang-tidy",
    )
    missing = False
    print("cp-run dependency check (optional tools are needed only for their features)")
    for name in dict.fromkeys((*required, *optional)):
        executable = shutil.which(name)
        version = ""
        if executable:
            try:
                probe = subprocess.run(
                    [executable, "--version"],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    timeout=5,
                    text=True,
                )
                version = next(iter(probe.stdout.splitlines()), "version unavailable")
                if name == "zsh":
                    match = re.search(r"zsh ([0-9]+)\.([0-9]+)", version)
                    if not match or tuple(map(int, match.groups())) < (5, 9):
                        missing = True
                        version += " [requires 5.9+]"
            except (OSError, subprocess.TimeoutExpired):
                version = "version probe failed"
        print(
            "  {}: {}{}{}".format(
                name,
                executable or "not installed",
                " [required]" if name in required else " [optional]",
                " — " + version if version else "",
            )
        )
        if name in required and not executable:
            missing = True
    return int(missing)


# Source: settings_schema.py
"""Interactive preferences embedded in the installed cp-run.zsh.

Only the marked native declaration block is rewritten. The editor parses data
with shlex; neither entered flags nor saved preferences are shell-evaluated.
"""

import copy
from contextlib import contextmanager
import os
from pathlib import Path
import re
import shlex
import stat
import subprocess
import tempfile


SCHOOL_C_FLAGS = (
    '-O2 -Wall -Werror -Wformat-security -Wignored-qualifiers -Winit-self '
    '-Wswitch-default -Wfloat-equal -Wpointer-arith -Wtype-limits -Wempty-body '
    '-Wno-logical-op -Wstrict-prototypes -Wold-style-declaration -Wold-style-definition '
    '-Wmissing-parameter-type -Wmissing-field-initializers -Wnested-externs '
    '-Wno-pointer-sign -Wno-unused-result -std=gnu99 -lm -lm'
).split()
SCHOOL_C_ONLY = {'-std=gnu99', '-Wstrict-prototypes', '-Wold-style-declaration',
                 '-Wold-style-definition', '-Wmissing-parameter-type', '-Wnested-externs',
                 '-Wno-pointer-sign'}
SCHOOL_CPP_FLAGS = [flag for flag in SCHOOL_C_FLAGS if flag not in SCHOOL_C_ONLY] + ['-std=gnu++17']


SETTINGS_BEGIN = '# CP_RUN_SETTINGS_BEGIN'
SETTINGS_END = '# CP_RUN_SETTINGS_END'
SETTINGS_GROUPS = {
    'common': 'MODE_FLAGS', 'gcc': 'MODE_GCC', 'clang': 'MODE_CLANG',
    'libstdc++': 'MODE_LIBSTDCXX', 'libc++': 'MODE_LIBCPP',
    'warnings-gcc': 'MODE_WARNINGS_GCC', 'warnings-clang': 'MODE_WARNINGS_CLANG',
    'cpp-common': 'MODE_CPP_FLAGS', 'c-common': 'MODE_C_FLAGS', 'c-gcc': 'MODE_C_GCC', 'c-clang': 'MODE_C_CLANG',
    'cpython': 'MODE_CPYTHON', 'pypy': 'MODE_PYPY',
}
# Keep metadata in the same copy/reset/delete transaction as compiler flags.
PROFILE_KEYS = ('MODE_KIND', 'MODE_CPU', 'MODE_DEST_DIR', 'MODE_SAVE_RELPATH',
                *SETTINGS_GROUPS.values())
PROFILE_DEFAULTS = {'MODE_KIND': 'flags', 'MODE_CPU': 'default'}

# These defaults mirror the native block. A regression test checks equality so
# reset cannot quietly diverge from a freshly downloaded script.
FACTORY_SETTINGS = {
    'MODE_CPP_FLAGS': {}, 'MODE_C_FLAGS': {}, 'MODE_C_GCC': {}, 'MODE_C_CLANG': {},
    'FORMAT_MODE': 'clang', 'DEFAULT_COMPILER': 'GCC', 'DEFAULT_STANDARD': 'auto',
    'DEFAULT_LANGUAGE': 'c++', 'LANGUAGE_COMPILERS': {},
    'DEFAULT_SOURCE': 'main.cpp',
    'DEFAULT_INPUT': 'in.txt',
    'DEFAULT_OUTPUT': 'out.txt', 'DEFAULT_ANSWER': 'ans.txt',
    'DEFAULT_REPORT': 'test_out', 'DEFAULT_SEPARATOR': r'\n\x1e\n',
    'DEFAULT_INTERPRETER': 'pypy3',
    'C_STANDARD': 'auto', 'C_SOURCE': 'main.c', 'PYTHON_SOURCE': 'main.py',
    'PYTHON_FLAGS': [], 'MODE_CPYTHON': {'debug': '-X dev -W default', 'extra': '-X dev -W error'},
    'MODE_PYPY': {'debug': '-W default -X track-resources', 'extra': '-W error -X track-resources'},
    'ACTION_DEST_DIR': {'test-mult': 'tests'}, 'ACTION_SAVE_RELPATH': {},
    'MODE_DEST_DIR': {}, 'MODE_SAVE_RELPATH': {},
    'DEFAULT_TEST_FOLDER': '{wsp-dir}/tests', 'NATIVE_FORMATTER': 'clang-format', 'PYTHON_FORMATTER': 'ruff', 'DEFAULT_REPORT_TESTS': 'all',
    'COMPANION_PORT': '27122', 'COMPANION_WAIT': '120',
    'MINIMIZE_ATTEMPTS': '200', 'MINIMIZE_SECONDS': '30', 'MAX_FAILURES': '10',
    'DEFAULT_LINE_LIMIT': '10000', 'DEFAULT_F_MODE': 'macro',
    'DEFAULT_MACRO': 'FILEO', 'DEFAULT_WORKSPACE': '.', 'EXTRA_WORKSPACES': [],
    'DEFAULT_DESTINATION': '.',
    'DEFAULT_BRUTE': 'brute.cpp', 'DEFAULT_GENERATOR': 'gen.cpp',
    'DEFAULT_ITERATIONS': '1000', 'DEFAULT_SEED': '4',

    'TIME_KILL_FACTOR': '2', 'MEMORY_KILL_FACTOR': '2',
    'DEFAULT_WARMUP': '1', 'DEFAULT_AVERAGE': '1',
    'DEFAULT_TIME_UNIT': 'ms', 'DEFAULT_MEMORY_UNIT': 'KiB',
    'MAX_LINE_BYTES': '1048576', 'MAX_CHECK_BYTES': '67108864',
    'MAX_REPORT_BYTES': '262144', 'MAX_REPORT_LINES': '10000',
    'MAX_SPOOL_BYTES': '268435456',
    'DEFAULT_FLAGS': ['-O2'],
    'WARNINGS_GCC': ['-Wall', '-Wextra', '-Wshadow', '-Wconversion',
                     '-Wduplicated-cond', '-Wlogical-op'],
    'WARNINGS_CLANG': ['-Wall', '-Wextra', '-Wshadow', '-Wconversion',
                       '-Wlogical-op-parentheses', '-Wtautological-compare'],
    'MODE_NAMES': ['debug', 'extra', 'pragma', 'pragma-fast', 'pragma-native'],
    'MODE_KIND': {'debug': 'debug', 'extra': 'debug', 'pragma': 'flags',
                  'pragma-fast': 'flags', 'pragma-native': 'flags'},
    'MODE_CPU': {'debug': 'default', 'extra': 'default', 'pragma': 'default',
                 'pragma-fast': 'default', 'pragma-native': 'native'},
    'MODE_FLAGS': {
        'debug': '-O2 -g2 -fsanitize=address,undefined -fsanitize=float-cast-overflow -fno-sanitize-recover=all -fno-omit-frame-pointer -DLOCAL',
        'extra': '-Og -g2 -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer -fno-optimize-sibling-calls -DLOCAL',
        'pragma': '-O3 -funroll-loops -Wunknown-pragmas',
        'pragma-fast': '-funroll-loops -fno-stack-protector -ffast-math -Wunknown-pragmas',
        'pragma-native': '-funroll-loops -fno-stack-protector -ffast-math -Wunknown-pragmas',
    },
    'MODE_GCC': {'debug': '', 'extra': '-fsanitize=float-cast-overflow,bounds-strict',
                 'pragma-fast': '-Ofast', 'pragma-native': '-Ofast'},
    'MODE_CLANG': {'debug': '', 'extra': '-fsanitize=float-cast-overflow,bounds',
                   'pragma-fast': '-O3', 'pragma-native': '-O3'},
    'MODE_LIBSTDCXX': {'debug': '-D_GLIBCXX_ASSERTIONS',
                      'extra': '-D_GLIBCXX_DEBUG -D_GLIBCXX_DEBUG_PEDANTIC'},
    'MODE_LIBCPP': {
        'debug': '-D_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_FAST',
        'extra': '-D_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_DEBUG',
    },
    'MODE_WARNINGS_GCC': {
        'debug': '',
        'extra': '-Wsign-conversion -Wnull-dereference -Wvla -Wfloat-equal -Wswitch-enum -Wformat=2 -Wpedantic -Wduplicated-branches -Warray-bounds=2',
    },
    'MODE_WARNINGS_CLANG': {
        'debug': '',
        'extra': '-Wsign-conversion -Wnull-dereference -Wvla -Wfloat-equal -Wswitch-enum -Wformat=2 -Wpedantic -Wunreachable-code -Warray-bounds',
    },
}


# The school verifier and native compilation preset share one immutable policy.
FACTORY_SETTINGS['MODE_NAMES'].append('school')
for _school_key in PROFILE_KEYS:
    if _school_key not in ('MODE_DEST_DIR', 'MODE_SAVE_RELPATH'):
        FACTORY_SETTINGS[_school_key]['school'] = PROFILE_DEFAULTS.get(_school_key, '')
FACTORY_SETTINGS['MODE_C_GCC']['school'] = shlex.join(SCHOOL_C_FLAGS)
FACTORY_SETTINGS['MODE_GCC']['school'] = shlex.join(SCHOOL_CPP_FLAGS)


def school_shell_policy():
    return ('typeset -gra SCHOOL_C_FLAGS=(' + shlex.join(SCHOOL_C_FLAGS) + ')\n' +
            'typeset -gra SCHOOL_CPP_FLAGS=(' + shlex.join(SCHOOL_CPP_FLAGS) + ')')


def normalize_school_preset(data):
    if 'school' not in data['MODE_NAMES']:
        return
    for key in PROFILE_KEYS:
        if key not in ('MODE_DEST_DIR', 'MODE_SAVE_RELPATH'):
            data[key]['school'] = FACTORY_SETTINGS[key]['school']


def read_settings(source):
    """Read the small declaration grammar without sourcing an editable file."""
    region = re.search(r'^# CP_RUN_SETTINGS_BEGIN\n(.*?)^# CP_RUN_SETTINGS_END$',
                       source, re.M | re.S)
    if region is None:
        raise ValueError('embedded settings block is missing')
    data = {}
    for line in region.group(1).splitlines():
        if not line or line.startswith('#'):
            continue
        match = re.fullmatch(r'typeset -g(a|A)? ([A-Z_]+)=(.*)', line)
        if not match:
            raise ValueError('invalid embedded settings declaration')
        kind, key, value = match.groups()
        if key in data:
            raise ValueError('duplicate setting: ' + key)
        if kind:
            if not value.startswith('(') or not value.endswith(')'):
                raise ValueError('invalid settings array: ' + key)
            words = shlex.split(value[1:-1])
            if kind == 'A':
                if len(words) % 2 or len(set(words[::2])) != len(words[::2]):
                    raise ValueError('invalid settings map: ' + key)
                data[key] = dict(zip(words[::2], words[1::2]))
            else:
                data[key] = words
        else:
            words = shlex.split(value)
            if len(words) != 1:
                raise ValueError('invalid scalar setting: ' + key)
            data[key] = words[0]
    return data


def settings_text(data):
    """Serialize values as quoted native declarations, never executable input."""
    lines = [SETTINGS_BEGIN,
             '# Managed by cp-run configure; ordinary launches read these native values directly.']
    for key, value in data.items():
        if not re.fullmatch(r'[A-Z_]+', key):
            raise ValueError('invalid settings key')
        if isinstance(value, dict):
            words = [word for pair in value.items() for word in pair]
            lines.append('typeset -gA {}=({})'.format(key, shlex.join(words)))
        elif isinstance(value, list):
            lines.append('typeset -ga {}=({})'.format(key, shlex.join(value)))
        else:
            lines.append('typeset -g {}={}'.format(key, shlex.quote(str(value))))
    return '\n'.join(lines) + '\n' + SETTINGS_END


def _settings_separator(value):
    """Decode only visible \\n, then validate the deliberately literal format."""
    decoded = value.replace(r'\n', '\n').replace(r'\x1e', '\x1e')
    allowed = set('\n\x1e abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#=_.:+-')
    if not decoded or decoded[0] != '\n' or decoded[-1] != '\n' or any(c not in allowed for c in decoded):
        raise ValueError(r'separator must start/end with \n; use ASCII letters, digits, spaces or #=_.:+-')
    return decoded




# Source: settings.py
"""Interactive preferences editor; serialization lives in settings_schema.py."""

def flag_key(flag):
    """Recognize value families while leaving independent warnings separate."""
    if re.fullmatch(r'-O(?:\d+|g|s|z|fast)?', flag):
        return '-O'
    if re.fullmatch(r'-g(?:\d+)?|-ggdb(?:\d+)?', flag):
        return '-g'
    if flag.startswith(('-D', '-U')):
        return 'macro:' + flag[2:].split('=', 1)[0]
    key = flag.split('=', 1)[0]
    if key in ('--std', '-std'):
        return '-std'
    if key.startswith('-Wno-'):
        return '-W' + key[5:]
    if key.startswith('-fno-'):
        return '-f' + key[5:]
    return key


def flag_units(words, python=False):
    """Keep known option/operand pairs intact during toggle operations."""
    paired = {'-I', '-L', '-l', '-D', '-U', '-isystem', '-iquote', '-include',
              '-imacros', '-isysroot', '--sysroot', '-target', '--target',
              '-arch', '-B', '-X', '-W', '--jit', '-Xlinker', '-Xclang', '-Xpreprocessor', '-mllvm'}
    if python:
        # -B and -I are standalone Python switches, but native driver options
        # with operands. Share the editor without sharing the wrong grammar.
        paired = {'-X', '-W', '--jit', '--check-hash-based-pycs'}
    units, index = [], 0
    while index < len(words):
        word = words[index]
        if not word.startswith('-') or word == '-':
            raise ValueError('expected a compiler flag, got {!r}'.format(word))
        unit = [word]
        if word in paired:
            index += 1
            if index == len(words):
                raise ValueError('missing operand for ' + word)
            unit.append(words[index])
        units.append(unit)
        index += 1
    return units


def _settings_unit_key(unit, python=False):
    if python and len(unit) == 1:
        return flag_key(unit[0])
    if unit[0] in ('-X', '-W', '--jit'):
        return unit[0] + ':' + unit[1].split('=', 1)[0]
    if unit[0] in ('-D', '-U'):
        return flag_key(unit[0] + unit[1])
    # Multiple include/link paths are independent, rather than replacing every
    # previous -I when a user adds a second directory.
    repeatable = ('-I', '-L', '-l', '-isystem', '-iquote', '-include', '-imacros', '-B')
    if unit[0] in repeatable:
        return unit[0] + ':' + unit[1]
    for prefix in ('-I', '-L', '-l', '-B'):
        if unit[0].startswith(prefix) and len(unit[0]) > len(prefix):
            return prefix + ':' + unit[0][len(prefix):]
    return flag_key(unit[0])


def _settings_change_flags(current, command, python=False):
    """Return a new list; a malformed edit cannot partially change settings."""
    action = 'toggle'
    for prefix in ('add ', 'remove '):
        if command.startswith(prefix):
            action, command = prefix.strip(), command[len(prefix):]
            break
    units = flag_units(current, python)
    for unit in flag_units(shlex.split(command), python):
        key = _settings_unit_key(unit, python)
        matches = [item for item in units if _settings_unit_key(item, python) == key]
        units = [item for item in units if _settings_unit_key(item, python) != key]
        if action != 'remove' and (action == 'add' or matches != [unit]):
            units.append(unit)
    return [word for unit in units for word in unit]


class _SettingsSave(Exception):
    pass


class _SettingsCancel(Exception):
    pass


class SettingsEditor:
    """One session owns pending data, undo history and the current reset scope."""

    def __init__(self, data):
        self.data = copy.deepcopy(data)
        self.history = []
        self.reset_action = lambda: self.replace(copy.deepcopy(FACTORY_SETTINGS))

    def replace(self, updated):
        if updated != self.data:
            self.history.append(copy.deepcopy(self.data))
            self.data.clear()
            self.data.update(updated)

    def set(self, key, value):
        updated = copy.deepcopy(self.data)
        updated[key] = value
        self.replace(updated)

    @contextmanager
    def scope(self, keys, profile=None):
        previous = self.reset_action

        def reset():
            updated = copy.deepcopy(self.data)
            for key in keys:
                if profile is None:
                    updated[key] = copy.deepcopy(FACTORY_SETTINGS[key])
                else:
                    fallback = PROFILE_DEFAULTS.get(key, '')
                    updated[key][profile] = FACTORY_SETTINGS[key].get(profile, fallback)
            self.replace(updated)

        self.reset_action = reset
        try:
            yield
        finally:
            self.reset_action = previous

    def ask(self, prompt):
        answer = input(prompt).strip()
        if any(c in answer for c in '\r\n\x00'):
            raise ValueError('enter one line; use visible \\n for a newline')
        if answer == 'save':
            raise _SettingsSave
        if answer in ('cancel', 'quit'):
            raise _SettingsCancel
        if answer == 'undo':
            if self.history:
                previous = self.history.pop()
                self.data.clear()
                self.data.update(previous)
                print('Undid the last edit.')
            else:
                print('Nothing to undo.')
            return None
        if answer == 'reset':
            self.reset_action()
            print('Restored factory values for this menu; not saved yet.')
            return None
        if answer == 'help':
            print('Choose a number or name. Enter keeps a value. back keeps pending edits.\n'
                  'undo reverses one edit; reset restores this menu; save reviews/writes; cancel discards.\n'
                  'Flags toggle: identical removes, another value replaces, new adds.\n'
                  'Use add FLAGS or remove FLAGS for an explicit operation. Quotes are data, never executed.')
            return None
        return answer


def _settings_scalar(editor, key, label, validator=None):
    value = editor.ask('{} [{}; Enter keeps it]: '.format(label, editor.data[key]))
    if value is None or value == '':
        return
    if validator is not None:
        value = validator(value)
    editor.set(key, value)


def _settings_compiler(value):
    aliases = {'gcc': 'GCC', 'g++': 'GCC', 'clang': 'clang++', 'clang++': 'clang++'}
    if value.lower() not in aliases:
        raise ValueError('choose GCC, gcc, g++, clang or clang++')
    return aliases[value.lower()]


def _settings_standard(value):
    if value != 'auto' and not re.fullmatch(r'(?:\d+|(?:gnu|c)\+\+[A-Za-z0-9]+)', value):
        raise ValueError('use auto, a number such as 23, or a native C++ standard name')
    return value


def _settings_positive(value, allow_inf=False):
    if allow_inf and value == 'inf':
        return value
    if not re.fullmatch(r'[0-9]{1,12}', value) or int(value) == 0:
        raise ValueError('use a positive integer of at most 12 digits' + (' or inf' if allow_inf else ''))
    return str(int(value))


def _settings_choice(*choices):
    def validate(value):
        if value not in choices:
            raise ValueError('choose ' + ' or '.join(choices))
        return value
    return validate


def _settings_filename(value):
    _settings_file_path(value)
    if not value.endswith(('.cpp', '.cc', '.cxx', '.C', '.c', '.py')):
        raise ValueError('use a C/C++/Python source path')
    return value


def _settings_file_path(value):
    """Saved file paths are literal; only a leading workspace token is special."""
    relative = workspace_path_suffix(value)
    if not value or relative == "":
        raise ValueError('use a filename, optionally prefixed with {wsp-dir}/')
    return value


def _settings_test_folder(value):
    """A literal directory, optionally rooted at the selected workspace."""
    if not value or any(char in value for char in "\x00\r\n"):
        raise ValueError('use a nonempty test folder')
    workspace_path_suffix(value)
    if '{' in value.replace('{wsp-dir}', '') or '}' in value.replace('{wsp-dir}', ''):
        raise ValueError('test filenames are fixed; only {wsp-dir} is a path placeholder')
    return value


def _settings_destination(value):
    """Match routing's lexical rules; physical containment is checked at use."""
    relative = workspace_path_suffix(value)
    if relative is not None:
        value_for_check = relative or '.'
    else:
        value_for_check = value
    if Path(value_for_check).is_absolute() or '..' in Path(value_for_check).parts:
        raise ValueError('use a workspace-relative path without .. components')
    return value


def _settings_macro(value):
    if not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', value):
        raise ValueError('use a C++ macro identifier, without -D or a value')
    return value


def _settings_seed(value):
    """Accept the generator's complete unsigned 64-bit range, including zero."""
    if not re.fullmatch(r'[0-9]{1,20}', value) or int(value) >= 2**64:
        raise ValueError('use an unsigned 64-bit integer (0 to 18446744073709551615)')
    return str(int(value))


def _settings_flags(editor, key, profile=None):
    with editor.scope([key], profile):
        _settings_flags_menu(editor, key, profile)


def _settings_flags_menu(editor, key, profile=None):
    while True:
        value = editor.data[key].get(profile, '') if profile else editor.data[key]
        current = shlex.split(value) if profile else value
        print('Flags: ' + (shlex.join(current) or '(none)'))
        command = editor.ask('flags> [flags / add / remove / clear / back]: ')
        if command is None:
            continue
        if command in ('', 'back'):
            return
        changed = [] if command == 'clear' else _settings_change_flags(
            current, command, python=key in ('PYTHON_FLAGS', 'MODE_CPYTHON', 'MODE_PYPY'))
        if profile:
            updated = dict(editor.data[key])
            updated[profile] = shlex.join(changed)
            editor.set(key, updated)
        else:
            editor.set(key, changed)


def _settings_fields(editor, title, fields):
    """A shared scalar menu keeps file/limit/stress behavior consistent."""
    with editor.scope([field[0] for field in fields]):
        while True:
            print('\n' + title)
            for i, (key, label, _) in enumerate(fields, 1):
                print('  {}. {}: {}'.format(i, label, editor.data[key]))
            choice = editor.ask('Choose a number, back, help, save or cancel: ')
            if choice is None:
                continue
            if choice in ('', 'back'):
                return
            if choice.isdecimal() and 1 <= int(choice) <= len(fields):
                key, label, validator = fields[int(choice) - 1]
                _settings_scalar(editor, key, label, validator)
            else:
                print('Choose a displayed number.')


def _settings_build(editor):
    with editor.scope(['DEFAULT_COMPILER', 'DEFAULT_STANDARD', 'DEFAULT_FLAGS']):
        while True:
            print('\nBuild\n  1. Compiler: {}\n  2. Standard: {}\n  3. Common flags: {}'.format(
                editor.data['DEFAULT_COMPILER'], editor.data['DEFAULT_STANDARD'],
                shlex.join(editor.data['DEFAULT_FLAGS']) or '(none)'))
            choice = editor.ask('build> [1–3 / back]: ')
            if choice is None:
                continue
            if choice in ('', 'back'):
                return
            if choice == '1':
                _settings_scalar(editor, 'DEFAULT_COMPILER', 'Compiler [GCC / clang++]', _settings_compiler)
            elif choice == '2':
                _settings_scalar(editor, 'DEFAULT_STANDARD', 'Standard [auto / 23 / c++26]', _settings_standard)
            elif choice == '3':
                _settings_flags(editor, 'DEFAULT_FLAGS')
            else:
                print('Choose 1, 2 or 3.')


def _settings_warnings(editor):
    with editor.scope(['WARNINGS_GCC', 'WARNINGS_CLANG']):
        while True:
            common = [flag for flag in editor.data['WARNINGS_GCC'] if flag in editor.data['WARNINGS_CLANG']]
            print('\nWarnings\n  1. Common: {}\n  2. GCC: {}\n  3. Clang: {}'.format(
                shlex.join(common) or '(none)', shlex.join(editor.data['WARNINGS_GCC']),
                shlex.join(editor.data['WARNINGS_CLANG'])))
            choice = editor.ask('warnings> [1–3 / back]: ')
            if choice is None:
                continue
            if choice in ('', 'back'):
                return
            if choice in ('2', '3'):
                _settings_flags(editor, 'WARNINGS_GCC' if choice == '2' else 'WARNINGS_CLANG')
            elif choice == '1':
                command = editor.ask('Common flags [flags / clear / back]: ')
                if command is None or command in ('', 'back'):
                    continue
                changed = [] if command == 'clear' else _settings_change_flags(common, command)
                updated = copy.deepcopy(editor.data)
                for key in ('WARNINGS_GCC', 'WARNINGS_CLANG'):
                    extras = [flag for flag in updated[key] if flag not in common]
                    updated[key] = changed + [flag for flag in extras if flag not in changed]
                editor.replace(updated)
            else:
                print('Choose 1, 2 or 3.')


def _settings_profile(editor, name):
    with editor.scope(PROFILE_KEYS, name):
        _settings_profile_menu(editor, name)


def _settings_profile_preview(editor, name, libraries=False):
    if name == 'school':
        print('school · GNU GCC · shared with school formatting')
        print('c → gcc: ' + shlex.join(SCHOOL_C_FLAGS))
        print('c++ → gcc: ' + shlex.join(SCHOOL_CPP_FLAGS))
        if libraries:
            print('  library: selected by the GNU C++ driver')
        return
    print('Configured flags; backend support is checked at build time.')
    print('CPU: {}; native selection is resolved at build time.'.format(
        editor.data['MODE_CPU'].get(name, 'default')))
    if not any(editor.data[key].get(name, '') for key in ('MODE_LIBSTDCXX', 'MODE_LIBCPP')):
        print('No standard-library-specific flags in this profile.')
    for language in ('c', 'c++', 'python'):
        print(language)
        backends = ('cpython', 'pypy') if language == 'python' else ('gcc', 'clang')
        for backend in backends:
            if language == 'python':
                words = list(editor.data['PYTHON_FLAGS'])
                words += shlex.split(editor.data[SETTINGS_GROUPS[backend]].get(name, ''))
            else:
                words = list(editor.data['DEFAULT_FLAGS'])
                words += list(editor.data['WARNINGS_GCC' if backend == 'gcc' else 'WARNINGS_CLANG'])
                groups = ['common', 'cpp-common', backend, 'warnings-' + backend]
                if language == 'c':
                    groups = ['common', 'c-common', 'c-' + backend, 'warnings-' + backend]
                for group in groups:
                    mapping = editor.data[SETTINGS_GROUPS[group]]
                    text = mapping.get(name, editor.data[SETTINGS_GROUPS[backend]].get(name, '')
                                       if group == 'c-' + backend else '')
                    words += shlex.split(text)
            print('  {}: {}'.format(backend, shlex.join(words) or '(none)'))
            if libraries and language == 'c++':
                for library in ('libstdc++', 'libc++'):
                    extra = shlex.split(editor.data[SETTINGS_GROUPS[library]].get(name, ''))
                    print('    {}: {}'.format(library, shlex.join(words + extra) or '(none)'))


def _settings_profile_languages(editor, name):
    while True:
        language = editor.ask('Language [c / c++ / python / back]: ')
        if language in ('', 'back'):
            return
        if language is None:
            continue
        backends = {'c': {'common': 'MODE_C_FLAGS', 'gcc': 'MODE_C_GCC', 'clang': 'MODE_C_CLANG'},
                    'c++': {'common': 'MODE_CPP_FLAGS', 'gcc': 'MODE_GCC', 'clang': 'MODE_CLANG'},
                    'python': {'cpython': 'MODE_CPYTHON', 'pypy': 'MODE_PYPY'}}
        if language not in backends:
            raise ValueError('choose c, c++ or python')
        for backend_name, key in backends[language].items():
            value = editor.data[key].get(name)
            if value is None and key in ('MODE_C_GCC', 'MODE_C_CLANG'):
                legacy = 'MODE_GCC' if key == 'MODE_C_GCC' else 'MODE_CLANG'
                value = editor.data[legacy].get(name, '')
                value = '(inherited) ' + (value or '(none)')
            print('  {}: {}'.format(backend_name, value or '(none)'))
        backend = editor.ask('Backend [{} / back]: '.format(' / '.join(backends[language])))
        if backend in backends[language]:
            _settings_flags(editor, backends[language][backend], name)


def _settings_profile_menu(editor, name):
    while name in editor.data['MODE_NAMES']:
        print('\nProfile {} ({})'.format(name, editor.data['MODE_KIND'][name]))
        print('  flags     Edit flags by language and backend')
        print('  advanced  Shared defaults, warnings, libraries and CPU')
        print('  preview   Language → backend; --lib library details')
        choice = editor.ask('profile> [flags / preview / advanced / kind / cpu / delete / back]: ')
        if choice is None:
            continue
        if choice in ('', 'back'):
            return
        if name == 'school' and choice in ('flags', 'advanced', 'cpu', 'kind'):
            print('School flags are shared with the verifier. Use profiles → new NAME school to customize a copy.')
            continue
        if choice == 'flags':
            _settings_profile_languages(editor, name)
        elif choice in ('preview', 'preview --lib'):
            _settings_profile_preview(editor, name, choice.endswith('--lib'))
        elif choice == 'advanced':
            groups = [group for group in SETTINGS_GROUPS if not group.startswith(('c-', 'cpp-'))]
            print('  cpu. Target CPU')
            for i, group in enumerate(groups, 1):
                print('  {}. {}: {}'.format(i, group, editor.data[SETTINGS_GROUPS[group]].get(name, '') or '(none)'))
            group = editor.ask('Group number/name, or back: ')
            if group is None:
                continue
            if group.isdecimal() and 1 <= int(group) <= len(groups):
                group = groups[int(group) - 1]
            if group == 'cpu':
                cpu = editor.ask('default or native: ')
                if cpu not in (None, ''):
                    changed = dict(editor.data['MODE_CPU'])
                    changed[name] = _settings_choice('default', 'native')(cpu)
                    editor.set('MODE_CPU', changed)
            elif group in SETTINGS_GROUPS:
                _settings_flags(editor, SETTINGS_GROUPS[group], name)
            elif group not in ('', 'back'):
                print('Choose a displayed group.')
        elif choice == 'kind':
            kind = editor.ask('debug (guard checks) or flags (native precedence): ')
            if kind not in (None, ''):
                kind = _settings_choice('debug', 'flags')(kind)
                changed = dict(editor.data['MODE_KIND'])
                changed[name] = kind
                editor.set('MODE_KIND', changed)
        elif choice == 'cpu':
            cpu = editor.ask('default (compiler target) or native (local CPU): ')
            if cpu not in (None, ''):
                cpu = _settings_choice('default', 'native')(cpu)
                changed = dict(editor.data['MODE_CPU'])
                changed[name] = cpu
                editor.set('MODE_CPU', changed)
        elif choice == 'delete':
            _settings_delete_profile(editor, name)
            return
        else:
            print('Use flags for common edits, cpu for targeting, preview to inspect, or advanced for adaptations.')


def _settings_delete_profile(editor, name):
    if name not in editor.data['MODE_NAMES']:
        raise ValueError('profile not found: ' + name)
    updated = copy.deepcopy(editor.data)
    updated['MODE_NAMES'].remove(name)
    for key in PROFILE_KEYS:
        updated[key].pop(name, None)
    editor.replace(updated)
    print('Deleted ' + name + '; undo restores it until you save.')


def _settings_profiles(editor):
    keys = ['MODE_NAMES', *PROFILE_KEYS]
    with editor.scope(keys):
        while True:
            print('\nProfiles: ' + (', '.join(editor.data['MODE_NAMES']) or '(none)'))
            command = editor.ask('profiles> [NAME / new / delete NAME / back]: ')
            if command is None:
                continue
            if command in ('', 'back'):
                return
            words = shlex.split(command)
            if words[0] == 'delete' and len(words) == 2:
                _settings_delete_profile(editor, words[1])
            elif words[0] == 'new' and len(words) <= 3:
                name = words[1] if len(words) >= 2 else editor.ask('New profile name: ')
                if name is None:
                    continue
                reserved = {'compile', 'run', 'test', 'stress', 'tr', 'sr', 'configure', 'pack', 'unpack', 'none', 'plain'}
                if not re.fullmatch(r'[A-Za-z][A-Za-z0-9_-]{0,31}', name) or name in reserved:
                    raise ValueError('start with a letter; use up to 32 letters/digits/_/-; avoid command names')
                if name in editor.data['MODE_NAMES']:
                    raise ValueError('that profile already exists')
                template = words[2] if len(words) == 3 else editor.ask('Template [saved profile name / plain]: ')
                if template is None:
                    continue
                if template != 'plain' and template not in editor.data['MODE_NAMES']:
                    raise ValueError('choose an existing profile or plain')
                updated = copy.deepcopy(editor.data)
                updated['MODE_NAMES'].append(name)
                for key in PROFILE_KEYS:
                    fallback = PROFILE_DEFAULTS.get(key, '')
                    if template != 'plain' and key in ('MODE_C_GCC', 'MODE_C_CLANG'):
                        if template not in updated[key]:
                            continue
                    updated[key][name] = updated[key].get(template, fallback) if template != 'plain' else fallback
                editor.replace(updated)
                _settings_profile(editor, name)
            elif len(words) == 1 and words[0] in editor.data['MODE_NAMES']:
                _settings_profile(editor, words[0])
            else:
                print('Example: new contest debug; or type extra to edit the existing profile.')


def save_settings(filename, original, data):
    """Validate a sibling replacement and retain the complete old file on failure."""
    data = validate_preferences(data)
    filename = Path(filename).resolve()
    if filename.read_text() != original:
        raise ValueError('script changed while editing; reopen cp-run configure')
    region = re.search(r'^# CP_RUN_SETTINGS_BEGIN\n.*?^# CP_RUN_SETTINGS_END$', original, re.M | re.S)
    if region is None:
        raise ValueError('embedded settings block is missing')
    updated = original[:region.start()] + settings_text(data) + original[region.end():]
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=filename.parent,
                                         prefix='.' + filename.name + '.', delete=False) as stream:
            temporary = Path(stream.name)
            os.fchmod(stream.fileno(), stat.S_IMODE(filename.stat().st_mode))
            stream.write(updated)
            stream.flush()
            os.fsync(stream.fileno())
        checked = subprocess.run(['/bin/zsh', '-n', str(temporary)], capture_output=True, text=True)
        if checked.returncode:
            raise ValueError('settings not saved: zsh syntax check failed')
        if filename.read_text() != original:
            raise ValueError('script changed while editing; reopen cp-run configure')
        os.replace(temporary, filename)
    finally:
        if temporary is not None and temporary.exists():
            temporary.unlink()


def _settings_finish(filename, original, initial, editor):
    changed = [(key, initial.get(key), value) for key, value in editor.data.items()
               if initial.get(key) != value]
    if not changed:
        print('No changes; nothing written.')
        return 0
    print('\nReview pending changes:')
    for key, before, after in changed:
        if isinstance(after, dict):
            for name in sorted(before.keys() | after.keys()):
                if before.get(name) != after.get(name):
                    print('  {} [{}]: {} -> {}'.format(key, name, before.get(name, '(unset)'), after.get(name, '(unset)')))
        else:
            print('  {}: {} -> {}'.format(key, repr(before), repr(after)))
    answer = input('Write these changes to this script? [y/N]: ').strip().lower()
    if answer not in ('y', 'yes'):
        print('Cancelled; nothing saved.')
        return 0
    save_settings(filename, original, editor.data)
    print('Saved in {}. No configuration file was created.'.format(filename))
    return 0


def _settings_workspaces(editor):
    with editor.scope(['DEFAULT_WORKSPACE', 'EXTRA_WORKSPACES']):
        while True:
            roots = [editor.data['DEFAULT_WORKSPACE'], *editor.data['EXTRA_WORKSPACES']]
            for i, root in enumerate(roots, 1):
                print('  {}. {}{}'.format(i, root, ' (main)' if i == 1 else ''))
            command = editor.ask('workspaces> [main PATH / add PATH / remove NUMBER / back]: ')
            if command is None:
                continue
            if command in ('', 'back'):
                return
            action, _, path = command.partition(' ')
            path = path.strip()
            if action == 'remove' and path.isdecimal() and 2 <= int(path) <= len(roots):
                del roots[int(path) - 1]
                editor.set('EXTRA_WORKSPACES', roots[1:])
            elif action in ('add', 'main') and path and '{wsp-dir}' not in path:
                path = os.path.expanduser(path)
                if path in (roots if action == 'add' else roots[1:]):
                    raise ValueError('workspace is already listed')
                if action == 'main':
                    editor.set('DEFAULT_WORKSPACE', path)
                else:
                    editor.set('EXTRA_WORKSPACES', [*roots[1:], path])
            else:
                print('Set the first path with main, add another path, or remove a number from 2 onward.')


def edit_settings(script_path):
    """Enter a pipe-testable menu; EOF/cancellation never writes preferences."""
    filename = Path(script_path).resolve()
    original = filename.read_text()
    initial = read_settings(original)
    editor = SettingsEditor(initial)
    files = [
        ('DEFAULT_SOURCE', 'Fallback source', _settings_filename),
        ('DEFAULT_WORKSPACE', 'Workspace path', None),
        ('DEFAULT_DESTINATION', 'Workspace-relative destination', _settings_destination),
        ('DEFAULT_INPUT', 'Input file', _settings_file_path), ('DEFAULT_ANSWER', 'Answer file', _settings_file_path),
        ('DEFAULT_OUTPUT', 'Program output: checks and -f auto/out', _settings_file_path),
        ('DEFAULT_REPORT', 'Test/stress report', _settings_file_path),
        ('DEFAULT_F_MODE', 'Bare -f action: macro (define FILEO) or auto (redirect files)', _settings_choice('macro', 'auto')),
        ('DEFAULT_MACRO', '-f macro identifier', _settings_macro),
    ]
    checks = [
        ('DEFAULT_SEPARATOR', r'Auto-test separator (visible \n)', lambda v: (_settings_separator(v), v)[1]),
        ('DEFAULT_LINE_LIMIT', 'Comparison row budget', _settings_positive),
        ('TIME_KILL_FACTOR', 'Time kill multiplier (>= 1)', lambda v: (_factor(v), v)[1]),
        ('MEMORY_KILL_FACTOR', 'Memory kill multiplier (>= 1)', lambda v: (_factor(v), v)[1]),
        ('MAX_LINE_BYTES', 'Maximum compared row bytes', _settings_positive),
        ('MAX_CHECK_BYTES', 'Checked bytes per case (both streams)', _settings_positive),
        ('MAX_REPORT_BYTES', 'Diagnostic bytes per failed case', _settings_positive),
        ('MAX_REPORT_LINES', 'Diagnostic rows per section', _settings_positive),
        ('MAX_SPOOL_BYTES', 'Maximum captured pipe/console bytes', _settings_positive),
    ]
    stress = [
        ('DEFAULT_BRUTE', 'Reference source', _settings_filename),
        ('DEFAULT_GENERATOR', 'Generator source', _settings_filename),
        ('DEFAULT_ITERATIONS', 'Stress iteration ceiling', _settings_positive),
        ('DEFAULT_SEED', 'Starting seed (unsigned 64-bit)', _settings_seed),
    ]
    measurements = [
        ('DEFAULT_WARMUP', 'Warm-up with -t/-m (0 or 1)', _settings_choice('0', '1')),
        ('DEFAULT_AVERAGE', 'Measured runs (0 means 1)', lambda v: str(repetition_count(v))),
        ('DEFAULT_TIME_UNIT', 'Displayed time unit', _settings_choice('s', 'ms')),
        ('DEFAULT_MEMORY_UNIT', 'Displayed memory unit', _settings_choice('B', 'KB', 'KiB', 'MB', 'MiB')),
    ]
    try:
        while True:
            print('\ncp-run settings')
            print('  files      Input, answers and sample folder')
            print('  workspaces Choose the main workspace and add other roots')
            print('  profiles   Create or edit build profiles')
            print('  tools      Choose language, compiler and interpreter')
            print('  paths      Source, workspace and output paths')
            print('  advanced   Build options, checks and measurements')
            try:
                choice = editor.ask('settings> [section / save / cancel / help]: ')
                if choice == 'advanced':
                    print('\nAdvanced settings')
                    sections = [
                        ('Build flags', '1'), ('Warnings', '3'),
                        ('Time, memory and comparison limits', '4'), ('Stress testing', '6'),
                        ('Measurements', '7'), ('Language and formatter options', '8'),
                        ('Sample imports and failure reports', '9'), ('Build destinations', '10'),
                    ]
                    for number, (label, _) in enumerate(sections, 1):
                        print('  {}. {}'.format(number, label))
                    print('  export FILE / import FILE / show')
                    choice = editor.ask('advanced> [number / command / back]: ')
                    if choice and choice.isdecimal():
                        if not 1 <= int(choice) <= len(sections):
                            raise ValueError('choose a displayed number')
                        choice = sections[int(choice) - 1][1]
                    if choice in ('', 'back'):
                        continue
                elif choice == 'paths':
                    choice = '2'
                elif choice == 'workspaces':
                    _settings_workspaces(editor)
                    continue
                elif choice == 'files':
                    _settings_fields(editor, 'Files', [
                        ('DEFAULT_INPUT', 'Read input from', _settings_file_path),
                        ('DEFAULT_ANSWER', 'Compare with', _settings_file_path),
                        ('DEFAULT_OUTPUT', 'Write output to', _settings_file_path),
                        ('DEFAULT_TEST_FOLDER', 'Numbered sample folder', _settings_test_folder),
                        ('DEFAULT_F_MODE', 'File I/O (-f): auto redirects files; macro defines a C/C++ macro', _settings_choice('macro', 'auto')),
                    ])
                    continue
                elif choice == 'tools':
                    with editor.scope(['DEFAULT_LANGUAGE', 'LANGUAGE_COMPILERS', 'DEFAULT_INTERPRETER']):
                        _settings_language_defaults(editor)
                    continue
                elif choice == 'profiles':
                    choice = '5'
                if choice is None:
                    continue
                if choice == '1':
                    _settings_build(editor)
                elif choice == '2':
                    _settings_fields(editor, 'Paths · {wsp-dir}/PATH starts at the selected workspace', files)
                elif choice == '3':
                    _settings_warnings(editor)
                elif choice == '4':
                    _settings_fields(editor, 'Checking & limits', checks)
                elif choice == '5':
                    _settings_profiles(editor)
                elif choice == '6':
                    _settings_fields(editor, 'Stress defaults', stress)
                elif choice == '7':
                    _settings_fields(editor, 'Measurements', measurements)
                elif choice == '8':
                    _settings_languages(editor)
                elif choice == '9':
                    _settings_fields(editor, 'Test files & integrations', [
                        ('DEFAULT_TEST_FOLDER', 'Test folder (fixed inN.txt / ansN.txt)', _settings_test_folder),
                        ('DEFAULT_REPORT_TESTS', 'Show test bodies', _settings_choice('all', 'failed')),
                        ('COMPANION_PORT', 'Companion port', _settings_positive),
                        ('COMPANION_WAIT', 'Companion wait seconds', _settings_positive),
                        ('MINIMIZE_ATTEMPTS', 'Reduction attempt ceiling', _settings_positive),
                        ('MINIMIZE_SECONDS', 'Reduction time seconds', _settings_positive),
                        ('MAX_FAILURES', 'Saved stress failures', _settings_positive),
                    ])
                elif choice == '10':
                    _settings_routing(editor)
                elif choice.startswith('export '):
                    export_preferences(choice[7:].strip(), editor.data, filename)
                    print('Exported pending preferences.')
                elif choice.startswith('import '):
                    updated = load_preferences(choice[7:].strip())
                    editor.replace(updated)
                    print('Imported into pending edits; save to apply.')
                elif choice == 'show':
                    for key, value in editor.data.items():
                        print('{}: {}'.format(key, repr(value)))
                else:
                    print('Choose files, profiles, tools or advanced. Type help for editing commands.')
            except ValueError as error:
                print('Not changed: ' + str(error))
    except _SettingsSave:
        try:
            return _settings_finish(filename, original, initial, editor)
        except (EOFError, KeyboardInterrupt):
            print('\nCancelled; nothing saved.')
            return 0
    except (_SettingsCancel, EOFError, KeyboardInterrupt):
        print('\nCancelled; nothing saved.')
        return 0


def _settings_languages(editor):
    with editor.scope(['DEFAULT_LANGUAGE', 'LANGUAGE_COMPILERS', 'DEFAULT_INTERPRETER', 'C_SOURCE', 'PYTHON_SOURCE', 'C_STANDARD', 'NATIVE_FORMATTER', 'PYTHON_FORMATTER', 'FORMAT_MODE', 'PYTHON_FLAGS']):
        _settings_languages_menu(editor)


def _settings_languages_menu(editor):
    """Language options stay separate from native optimization/warning lists."""
    while True:
        print('\nLanguages & tools: 1. Interpreter/source/standard/tools  2. Python flags  3. Language/compiler defaults  back')
        choice = editor.ask('languages> ')
        if choice in ('', 'back'): return
        if choice == '1':
            _settings_fields(editor, 'Language settings', [
                ('DEFAULT_INTERPRETER', 'Python interpreter (python3, pypy3 or path)', None),
                ('C_SOURCE', 'C fallback source', _settings_filename),
                ('PYTHON_SOURCE', 'Python fallback source', _settings_filename),
                ('C_STANDARD', 'C standard (auto or native spelling)', None),
                ('FORMAT_MODE', 'Format mode (clang or school)', _settings_choice('clang', 'school')),
                ('NATIVE_FORMATTER', 'C/C++ formatter executable', None),
                ('PYTHON_FORMATTER', 'Python formatter (ruff or black)', None),
            ])
        elif choice == '2': _settings_flags(editor, 'PYTHON_FLAGS')
        elif choice == '3': _settings_language_defaults(editor)


def _settings_language_defaults(editor):
    """Edit language preferences with ordinary names; no map syntax required."""
    while True:
        print('\nLanguage defaults\n  1. Preferred source language: ' + editor.data['DEFAULT_LANGUAGE'])
        for number, language in ((2, 'c'), (3, 'c++')):
            print('  {}. {} compiler: {}'.format(number, language, editor.data['LANGUAGE_COMPILERS'].get(language, 'inherit (' + editor.data['DEFAULT_COMPILER'] + ')')))
        print('  4. Python interpreter: ' + editor.data['DEFAULT_INTERPRETER'])
        choice = editor.ask('language defaults> ')
        if choice in ('', 'back'): return
        if choice == '1':
            _settings_scalar(editor, 'DEFAULT_LANGUAGE', 'Language [c++ / c / python / auto]', _settings_choice('c++', 'c', 'python', 'auto'))
        elif choice in ('2', '3'):
            language = 'c' if choice == '2' else 'c++'
            value = editor.ask(language + ' compiler [GCC / clang / inherit; Enter keeps it]: ')
            if value:
                updated = dict(editor.data['LANGUAGE_COMPILERS'])
                if value == 'inherit': updated.pop(language, None)
                else: updated[language] = _settings_compiler(value)
                editor.set('LANGUAGE_COMPILERS', updated)
        elif choice == '4':
            _settings_scalar(editor, 'DEFAULT_INTERPRETER', 'Interpreter [pypy3 / python3 / absolute path]')


def _settings_routing(editor):
    with editor.scope(['ACTION_DEST_DIR', 'ACTION_SAVE_RELPATH', 'MODE_DEST_DIR', 'MODE_SAVE_RELPATH']):
        _settings_routing_menu(editor)


def _settings_routing_menu(editor):
    """A small command menu edits optional overrides without JSON syntax."""
    actions = ('ordinary', 'compile', 'debug', 'run', 'test', 'test-auto', 'test-mult', 'stress', 'companion')
    while True:
        print('\nActions: ' + ', '.join(actions))
        print('Or enter profile NAME. Values inherit unless explicitly set.')
        selection = editor.ask('routing> [ACTION / profile NAME / back]: ')
        if selection in ('', 'back'): return
        if selection is None: continue
        profile = selection.startswith('profile ')
        name = selection[8:].strip() if profile else selection
        if name not in (editor.data['MODE_NAMES'] if profile else actions):
            print('Choose an action or a saved profile.'); continue
        prefix = 'MODE_' if profile else 'ACTION_'
        fields = {'dest-dir': prefix + 'DEST_DIR', 'save-relpath': prefix + 'SAVE_RELPATH'}
        while True:
            for label, key in fields.items(): print('  {}: {}'.format(label, editor.data[key].get(name, '(inherit)')))
            command = editor.ask('routing {}> [FIELD VALUE / inherit FIELD / back]: '.format(name))
            if command in ('', 'back'): break
            if command is None: continue
            words = shlex.split(command)
            if len(words) != 2: print('Example: dest-dir build/debug; or inherit dest-dir'); continue
            inherit = words[0] == 'inherit'
            field = words[1] if inherit else words[0]
            if field not in fields: print('Use dest-dir or save-relpath.'); continue
            key = fields[field]
            value = '' if inherit else words[1]
            if not inherit:
                if field == 'dest-dir': _settings_destination(value)
                else: _settings_choice('0', '1')(value)
            mapping = dict(editor.data[key])
            if inherit: mapping.pop(name, None)
            else: mapping[name] = value
            editor.set(key, mapping)


# Source: preferences.py
"""Validated data-only preferences transfer; no runtime config lookup."""


def validate_preferences(values):
    """Validate a complete or older-schema settings record without a compiler."""
    if not isinstance(values, dict):
        raise ValueError('invalid settings object')
    values = copy.deepcopy(values)
    # Old exports may carry templates and inherited routing. Keep an explicit
    # old folder, but fixed filenames replace all per-case path expressions.
    for retired in ('DEFAULT_TIMEOUT', 'DEFAULT_MEMORY_LIMIT', 'CHECK_TIMEOUT', 'CHECK_MEMORY_LIMIT'):
        values.pop(retired, None)
    old_folder = values.pop('DEFAULT_TEST_DIR', '')
    if not isinstance(old_folder, str):
        raise ValueError('invalid legacy test folder')
    if old_folder and 'DEFAULT_TEST_FOLDER' not in values:
        values['DEFAULT_TEST_FOLDER'] = old_folder if old_folder.startswith('{wsp-dir}') else '{wsp-dir}/' + old_folder
    for key in ('DEFAULT_INPUT_TEMPLATE', 'DEFAULT_ANSWER_TEMPLATE', 'MANUAL_SEPARATOR',
                'ACTION_SAVE_TEST_RELPATH', 'MODE_SAVE_TEST_RELPATH', 'DEFAULT_RELPATH_DESTINATION'):
        values.pop(key, None)
    if set(values) - set(FACTORY_SETTINGS):
        raise ValueError('unknown settings keys or invalid settings object')
    data = copy.deepcopy(FACTORY_SETTINGS)
    data.update(copy.deepcopy(values))
    for key, factory in FACTORY_SETTINGS.items():
        value = data[key]
        if type(value) is not type(factory):
            raise ValueError('invalid type for ' + key)
        strings = list(value.values()) if isinstance(value, dict) else value if isinstance(value, list) else [value]
        if isinstance(value, dict) and any(not isinstance(k, str) for k in value):
            raise ValueError('invalid profile key in ' + key)
        if any(not isinstance(v, str) or any(c in v for c in '\x00\r\n') for v in strings):
            raise ValueError('invalid text in ' + key + '; use visible \\n escapes')
    _settings_choice('clang', 'school')(data['FORMAT_MODE'])
    data['DEFAULT_COMPILER'] = _settings_compiler(data['DEFAULT_COMPILER'])
    _settings_standard(data['DEFAULT_STANDARD'])
    _settings_choice('c++', 'c', 'python', 'auto')(data['DEFAULT_LANGUAGE'])
    if set(data['LANGUAGE_COMPILERS']) - {'c', 'c++'}:
        raise ValueError('compiler overrides support c and c++ only; use DEFAULT_INTERPRETER for Python')
    data['LANGUAGE_COMPILERS'] = {key: _settings_compiler(value) for key, value in data['LANGUAGE_COMPILERS'].items()}
    if data['C_STANDARD'] != 'auto' and not re.fullmatch(r'(?:[0-9]+|(?:gnu|c)[0-9][A-Za-z0-9]*|iso9899:[0-9]+)', data['C_STANDARD']): raise ValueError('invalid C standard')
    _settings_filename(data['DEFAULT_SOURCE'])
    for key in ('DEFAULT_BRUTE', 'DEFAULT_GENERATOR'):
        _settings_filename(data[key])
    for key in ('DEFAULT_LINE_LIMIT', 'DEFAULT_ITERATIONS', 'MAX_LINE_BYTES', 'MAX_CHECK_BYTES',
                'MAX_REPORT_BYTES', 'MAX_REPORT_LINES', 'MAX_SPOOL_BYTES'):
        data[key] = _settings_positive(data[key])
    _settings_seed(data['DEFAULT_SEED'])
    _settings_separator(data['DEFAULT_SEPARATOR'])
    _settings_macro(data['DEFAULT_MACRO'])
    _settings_choice('macro', 'auto')(data['DEFAULT_F_MODE'])
    _settings_choice('0', '1')(data['DEFAULT_WARMUP'])
    for key in ('TIME_KILL_FACTOR', 'MEMORY_KILL_FACTOR'):
        _factor(data[key])
    data['DEFAULT_AVERAGE'] = str(repetition_count(data['DEFAULT_AVERAGE']))
    _settings_choice('s', 'ms')(data['DEFAULT_TIME_UNIT'])
    _settings_choice('B', 'KB', 'KiB', 'MB', 'MiB')(data['DEFAULT_MEMORY_UNIT'])
    if not data['DEFAULT_DESTINATION']: raise ValueError('empty destination')
    _settings_destination(data['DEFAULT_DESTINATION'])
    for key in ('DEFAULT_WORKSPACE', 'DEFAULT_INPUT', 'DEFAULT_OUTPUT', 'DEFAULT_ANSWER', 'DEFAULT_REPORT'):
        if not data[key]: raise ValueError('empty setting: ' + key)
    for key in ('DEFAULT_INPUT', 'DEFAULT_OUTPUT', 'DEFAULT_ANSWER', 'DEFAULT_REPORT'):
        _settings_file_path(data[key])
    roots = [data['DEFAULT_WORKSPACE'], *data['EXTRA_WORKSPACES']]
    if not all(roots) or len(roots) != len(set(roots)):
        raise ValueError('workspace paths must be nonempty and distinct')
    if any('{wsp-dir}' in root for root in roots):
        raise ValueError('workspace path cannot refer to itself with {wsp-dir}')
    # Optional map entries inherit; an explicit zero remains a real override.
    actions = {'ordinary', 'compile', 'debug', 'run', 'test', 'test-auto', 'test-mult', 'stress', 'companion'}
    for key in ('ACTION_DEST_DIR', 'ACTION_SAVE_RELPATH'):
        if set(data[key]) - actions: raise ValueError('unknown action in ' + key)
    for key in ('MODE_DEST_DIR', 'MODE_SAVE_RELPATH'):
        data[key] = {name: value for name, value in data[key].items() if value != ''}
    for key in ('ACTION_DEST_DIR', 'MODE_DEST_DIR'):
        for value in data[key].values():
            if not value: raise ValueError('empty destination override')
            _settings_destination(value)
    for key in ('ACTION_SAVE_RELPATH', 'MODE_SAVE_RELPATH'):
        for value in data[key].values(): _settings_choice('0', '1')(value)
    _settings_test_folder(data['DEFAULT_TEST_FOLDER'])
    for key in ('C_SOURCE', 'PYTHON_SOURCE'): _settings_filename(data[key])
    _settings_choice('all', 'failed')(data['DEFAULT_REPORT_TESTS'])
    for key in ('COMPANION_PORT', 'COMPANION_WAIT', 'MINIMIZE_ATTEMPTS', 'MINIMIZE_SECONDS', 'MAX_FAILURES'):
        _settings_positive(data[key])
    if int(data['COMPANION_PORT']) > 65535: raise ValueError('port must be 1..65535')
    if not data['DEFAULT_INTERPRETER']: raise ValueError('empty interpreter')
    flag_units(data['PYTHON_FLAGS'], python=True)
    names = data['MODE_NAMES']
    for key in PROFILE_KEYS:
        if key not in values: data[key] = {name: value for name, value in data[key].items() if name in names}
    if len(set(names)) != len(names): raise ValueError('duplicate profile name')
    reserved = {'companion', 'compile', 'run', 'test', 'stress', 'tr', 'sr', 'configure', 'pack', 'unpack', 'none', 'plain'}
    for name in names:
        if not re.fullmatch(r'[A-Za-z][A-Za-z0-9_-]{0,31}', name) or name in reserved:
            raise ValueError('invalid profile name: ' + name)
        if data['MODE_KIND'].get(name) not in ('debug', 'flags'):
            raise ValueError('invalid profile kind: ' + name)
        if data['MODE_CPU'].get(name, 'default') not in ('default', 'native'):
            raise ValueError('invalid profile CPU policy: ' + name)
    for key in PROFILE_KEYS:
        if set(data[key]) - set(names): raise ValueError('unknown profile in ' + key)
    normalize_school_preset(data)
    # Validate the shell-word grammar while preserving the original spelling.
    for key in ('DEFAULT_FLAGS', 'WARNINGS_GCC', 'WARNINGS_CLANG'):
        flag_units(data[key])
    for key in SETTINGS_GROUPS.values():
        for text in data[key].values(): shlex.split(text)
    return data


def export_preferences(path, data, script_path):
    """Write an atomic portable export; never overwrite the installed script."""
    destination = Path(path)
    if destination.resolve() == Path(script_path).resolve():
        raise ValueError('settings export must not overwrite the script')
    data = validate_preferences(data)
    record = {'format': 'cp-run-settings', 'schema': 3, 'settings': data}
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=destination.parent,
                                         prefix='.cp-run-settings-', delete=False) as stream:
            temporary = Path(stream.name)
            json.dump(record, stream, indent=2, ensure_ascii=True)
            stream.write('\n'); stream.flush(); os.fsync(stream.fileno())
        os.replace(temporary, destination)
    finally:
        if temporary is not None: temporary.unlink(missing_ok=True)


def load_preferences(path):
    """Reject oversized/ambiguous JSON before it can alter native preferences."""
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result: raise ValueError('duplicate settings key: ' + key)
            result[key] = value
        return result
    with open(path, 'rb') as stream: raw = stream.read(4 * 1024 * 1024 + 1)
    if len(raw) > 4 * 1024 * 1024: raise ValueError('settings export exceeds 4 MiB')
    try:
        record = json.loads(raw, object_pairs_hook=unique)
    except RecursionError:
        raise ValueError('settings export is too deeply nested') from None
    if (not isinstance(record, dict) or set(record) != {'format', 'schema', 'settings'}
            or record['format'] != 'cp-run-settings' or type(record['schema']) is not int
            or record['schema'] not in (1, 2, 3)):
        raise ValueError('unsupported settings export format/schema')
    return validate_preferences(record['settings'])


def transfer_preferences(action, script, path):
    filename = Path(script).resolve()
    original = filename.read_text()
    if action == 'export':
        export_preferences(path, read_settings(original), script)
    else:
        save_settings(filename, original, load_preferences(path))
    print('cp-run: settings {}: {}'.format('exported' if action == 'export' else 'imported', path), file=sys.stderr)
    return 0


def remember_launch(config):
    """Commit only the main candidate after spawn; repeats do not rewrite history."""
    path = config.get('history_binary')
    if not path or config.get('_remembered'): return
    config['_remembered'] = True
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=Path(path).parent, prefix='.launch-', delete=False) as stream:
            temporary = Path(stream.name)
            fields = [config['executable']]
            if config['executable'].endswith('.py'):
                fields.extend(['CP_RUN_ARGV_V1', *config.get('main_argv', [config['executable']])])
            stream.write(b''.join(os.fsencode(value) + b'\0' for value in fields))
        os.replace(temporary, path)
    except OSError as error:
        print('cp-run: warning: launch history not saved: ' + str(error), file=sys.stderr)
    finally:
        if temporary is not None:
            try: temporary.unlink(missing_ok=True)
            except OSError: pass  # History failure must not abort a spawned program.


# Source: bridge.py
"""Counted argv bridge between native parsing and the embedded services."""


def _bridge_config(values):
    """Decode lengths instead of guessing delimiters inside user arguments."""
    values = iter(values)
    pairs = int(next(values))
    config = {next(values): next(values) for _ in range(pairs)}
    runtime_count = int(next(values))
    config['runtime_args'] = [next(values) for _ in range(runtime_count)]
    protected_count = int(next(values))
    config['protected'] = [next(values) for _ in range(protected_count)]
    for key in ('auto', 'cin', 'cout', 'show_time', 'show_memory', 'show_command', 'warmup', 'mult', 'overwrite', 'stop_on_failure', 'review', 'annotate', 'format_cache'):
        config[key] = config.get(key, '0') == '1'
    config['cases'] = [int(value) for value in config.get('cases', '').split(',') if value]
    for key in ('num_test', 'seed'):
        if config.get(key, '') == '':
            config.pop(key, None)
    if 'format_source_count' in config:
        config['format_sources'] = [config['format_source_' + str(index)] for index in range(1, int(config['format_source_count']) + 1)]
    for role in ('main', 'brute', 'generator'):
        count = int(config.get('launch_' + role + '_count', 0))
        if count:
            config[role + '_argv'] = [config['launch_{}_{}'.format(role, i)] for i in range(1, count + 1)]
    return config


def _bridge_main():
    if sys.version_info < (3, 9):
        print('cp-run: this feature requires Python 3.9+', file=sys.stderr)
        return 127
    action = sys.argv[1]
    if action == 'settings':
        return edit_settings(sys.argv[2])
    if action in ('import', 'export'):
        return transfer_preferences(action, sys.argv[2], sys.argv[3])
    config = _bridge_config(sys.argv[2:])
    if action == 'companion': return execute_companion(config)
    if action == 'format': return execute_format(config)
    if action == 'strict-format': return execute_strict_format(config)
    if action == 'doctor': return execute_doctor(config)
    if action in ('pack', 'unpack'): return execute_bundle(config)
    if action == 'ce': return compilation_report(config)
    if action == 'preflight':
        preflight_check(config)
        return 0
    if action == 'test':
        return execute_test(config)
    if action == 'stress':
        return execute_stress(config)
    if action == 'supervise':
        return supervise(config)
    raise CheckUsageError('unknown internal operation: ' + action)


try:
    _bridge_status = _bridge_main()
except CheckUsageError as _bridge_error:
    print('cp-run: ' + str(_bridge_error), file=sys.stderr)
    _bridge_status = 2
except (CheckSetupError, OSError) as _bridge_error:
    print('cp-run: ' + str(_bridge_error), file=sys.stderr)
    _bridge_status = 1
except ValueError as _bridge_error:
    print('cp-run: ' + str(_bridge_error), file=sys.stderr)
    _bridge_status = 2
except KeyboardInterrupt:
    _bridge_status = 130
raise SystemExit(_bridge_status)
CP_RUN_PYTHON
}

main "$@"
