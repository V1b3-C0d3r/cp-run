#!/bin/zsh -f
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 cp-run contributors
# One C, C++ or Python source, one selected output, and an optional run. Requires zsh 5.9.

# Start from native, predictable options instead of inheriting interactive
# customizations. Expected failures are checked explicitly, without ERR_EXIT.
emulate -LR zsh
setopt NO_UNSET PIPE_FAIL EXTENDED_GLOB
unsetopt ALIASES
typeset -r PROGRAM=cp-run VERSION=1.1
typeset -r SCRIPT_PATH=${0:A} # Settings follow the real script when invoked through a symlink.

# CP_RUN_SETTINGS_BEGIN
# Managed by --set-defaults; ordinary launches read these native values directly.
typeset -g DEFAULT_COMPILER=GCC
typeset -g DEFAULT_STANDARD=auto
typeset -g DEFAULT_LANGUAGE=c++
typeset -gA LANGUAGE_COMPILERS=()
typeset -g DEFAULT_SOURCE=main.cpp
typeset -g DEFAULT_TIMEOUT=inf
typeset -g DEFAULT_MEMORY_LIMIT=inf
typeset -g DEFAULT_INPUT=input.txt
typeset -g DEFAULT_OUTPUT=output.txt
typeset -g DEFAULT_ANSWER=ans.txt
typeset -g DEFAULT_REPORT=test_out
typeset -g DEFAULT_SEPARATOR='\n\x1e\n'
typeset -g MANUAL_SEPARATOR='\n###\n'
typeset -g DEFAULT_INTERPRETER=pypy3
typeset -g C_STANDARD=auto
typeset -g C_SOURCE=main.c
typeset -g PYTHON_SOURCE=main.py
typeset -ga PYTHON_FLAGS=()
typeset -gA MODE_CPYTHON=(debug '-X dev -W default' extra '-X dev -W error')
typeset -gA MODE_PYPY=(debug '-W default -X track-resources' extra '-W error -X track-resources')
typeset -gA ACTION_DEST_DIR=(test-mult tests)
typeset -gA ACTION_SAVE_RELPATH=()
typeset -gA ACTION_SAVE_TEST_RELPATH=()
typeset -gA MODE_DEST_DIR=()
typeset -gA MODE_SAVE_RELPATH=()
typeset -gA MODE_SAVE_TEST_RELPATH=()
typeset -g DEFAULT_INPUT_TEMPLATE='./{n}.in'
typeset -g DEFAULT_ANSWER_TEMPLATE='./{n}.ans'
typeset -g DEFAULT_TEST_DIR=''
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
typeset -g DEFAULT_DESTINATION=.
typeset -g DEFAULT_RELPATH_DESTINATION=.
typeset -g DEFAULT_BRUTE=brute.cpp
typeset -g DEFAULT_GENERATOR=gen.cpp
typeset -g DEFAULT_ITERATIONS=1000
typeset -g DEFAULT_SEED=4
typeset -g CHECK_TIMEOUT=1500
typeset -g CHECK_MEMORY_LIMIT=256
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
typeset -ga MODE_NAMES=(debug extra pragma pragma-fast pragma-native)
typeset -gA MODE_KIND=(debug debug extra debug pragma flags pragma-fast flags pragma-native flags)
typeset -gA MODE_CPU=(debug default extra default pragma default pragma-fast default pragma-native native)
typeset -gA MODE_FLAGS=(debug '-O2 -g2 -fsanitize=address,undefined -fsanitize=float-cast-overflow -fno-sanitize-recover=all -fno-omit-frame-pointer -DLOCAL' extra '-Og -g2 -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer -fno-optimize-sibling-calls -DLOCAL' pragma '-O3 -funroll-loops -Wunknown-pragmas' pragma-fast '-funroll-loops -fno-stack-protector -ffast-math -Wunknown-pragmas' pragma-native '-funroll-loops -fno-stack-protector -ffast-math -Wunknown-pragmas')
typeset -gA MODE_GCC=(debug '' extra -fsanitize=float-cast-overflow,bounds-strict pragma-fast -Ofast pragma-native -Ofast)
typeset -gA MODE_CLANG=(debug '' extra -fsanitize=float-cast-overflow,bounds pragma-fast -O3 pragma-native -O3)
typeset -gA MODE_LIBSTDCXX=(debug -D_GLIBCXX_ASSERTIONS extra '-D_GLIBCXX_DEBUG -D_GLIBCXX_DEBUG_PEDANTIC')
typeset -gA MODE_LIBCPP=(debug -D_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_FAST extra -D_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_DEBUG)
typeset -gA MODE_WARNINGS_GCC=(debug '' extra '-Wsign-conversion -Wnull-dereference -Wvla -Wfloat-equal -Wswitch-enum -Wformat=2 -Wpedantic -Wduplicated-branches -Warray-bounds=2')
typeset -gA MODE_WARNINGS_CLANG=(debug '' extra '-Wsign-conversion -Wnull-dereference -Wvla -Wfloat-equal -Wswitch-enum -Wformat=2 -Wpedantic -Wunreachable-code -Warray-bounds')
# CP_RUN_SETTINGS_END


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
       cp-run run [TARGET] [OPTION]... [-- PROGRAM-ARG...]
       cp-run test[=auto|mult] [run] [CASE...] [FILE [IN [ANS [REPORT]]]] [OPTION]...
       cp-run stress [run] [MAIN [BRUTE [GEN]]] [OPTION]...
       cp-run companion [FILE] [OPTION]...
       cp-run --pack=in|ans [DIR [BUNDLE]] [OPTION]...
       cp-run --unpack=in|ans [BUNDLE [DIR]] [OPTION]...

Build, debug and check C++, C and Python with GCC, Clang, CPython or PyPy.
FILE is discovered locally; conventional sources are main.cpp/main.c/main.py.
Requires zsh 5.9; advanced features require Python 3.9+ (standard library only).

Commands:
  compile                 Prepare only; print the absolute launch-target path
  debug[=PROFILE]          Run a diagnostic profile: debug or deeper extra
  run                     Run a native executable or Python source
  test[=auto|mult]         Whole input / separated cases / numbered file pairs
  stress                  Compare MAIN with BRUTE on inputs generated by GEN
  companion               Receive one problem from Competitive Companion
  test run, stress run    Check existing targets without preparation
  tr, sr                  test run - / stress run -; reuse the last primary target

Language and build:
  --compiler=NAME         GCC/gcc/g++ (default), clang/clang++; any position
  --interpreter-arg=ARG   Repeatable Python option (also preserves exact replay)
  --interpreter=NAME      User Python executable; default pypy3
  --language=NAME         Omitted-source preference: c++, c, python or auto
  -std=VALUE              Numeric/native C or C++ alias; newest advertised by default
  --profile=NAME          Saved debug/flags profile; pragma[-fast|-native] are native
  --no-w                  Omit generated baseline warnings
  -o PATH, -oPATH         Exact native output; overrides artifact routing
  -f, --file-io           Saved action; factory action defines FILEO (native only)
  -f=auto [IN [OUT]]      Redirect both streams; defaults input.txt/output.txt
  -f=in [IN], -f=out [OUT] Redirect only the selected stream
  --make-prettier[=MODE]  Format before build; only/check exit; standalone formats

Routing and checking:
  --wsp-dir=DIR           Workspace path; default ./; value is required
  --wsp-name=NAME         Search ancestors, or check an explicit workspace
  --dest-dir=DIR          Workspace-relative destination; action/profile configurable
  --save-relpath[=0|1]    Preserve artifact subtree; bare means 1
  --find=NAME             Find an omitted target under destination/subtree
  --test-dir=DIR          Separate mult/Companion data root
  --save-test-relpath[=0|1] Preserve the test-data subtree independently
  --in-tmp=PATTERN        Input template: ./{n}.in; {n} and {stem} placeholders
  --ans-tmp=PATTERN       Answer template: ./{n}.ans
  --sep=TEXT              Internal separator; default visible escape '\n\x1e\n'
  --text                  Pack/unpack manual files using the saved text marker
  --text-sep=TEXT         Manual-file pack/unpack conversion; default '\n###\n'
  --bundle-format=FORMAT auto: legacy uncounted (default) or counted pack output
  --source=FILE           Source anchor for pack/unpack templates; no compilation
  --overwrite             Replace planned import/unpack files (default: refuse)
  --test-iters=N          Independent-case cap / stress count; whole-test time factor
  --report-tests=all|failed Show all payloads (default) or failed payloads only
  --cin, --cout           Framed console test input / console checking protocol
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
  --set-defaults          Interactive settings saved inside this script
  --export-settings=FILE, --import-settings=FILE Portable data-only preferences
  --help, --version       Show help / cp-run and compiler versions

Values accept '=' or a separate operand: --wsp-dir DIR, -std 23, -f auto.
Required values cannot be empty. FILE - recalls source/target; ./- is literal.
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

parse_cli() {
    local arg value consumed=0 slots=1 f_count=0
    local -a positionals=()

    # Shorthands insert only the primary FILE; the ordinary parser still owns
    # test data, stress roles and both compiler/runtime argument boundaries.
    case "${1-}" in
        tr) shift; set -- test run - "$@" ;;
        sr) shift; set -- stress run - "$@" ;;
    esac

    # Only the first word is an operation selector. Prefix a colliding file
    # name with './'; filenames are not reinterpreted later in the argv list.
    if (( $# )); then
        case "$1" in
            --pack|--pack=*|--unpack|--unpack=*)
                arg=$1; shift; take_value "$@"; (( ! consumed )) || shift
                action=${arg%%=*}; action=${action#--}; bundle_stream=$value ;;
            compile|run|stress|companion) action=$1; shift ;;
            debug|debug=*)
                action=debug; value=${1#debug}; value=${value#=}
                select_profile "${value:-debug}"; shift ;;
            test=mult) action=test; mult=1; shift ;;
            test|test=|test=auto) action=test; [[ $1 != test=auto ]] || auto=1; shift ;;
            test=*) fail 'test supports normal mode or test=auto; test=manual was removed' ;;
        esac
    fi
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
    case "$action" in test) slots=4 ;; stress) slots=3 ;; pack|unpack) slots=2 ;; esac
    while (( $# && ${#positionals} < slots )) && { [[ $1 != -* ]] || { (( ! ${#positionals} )) && [[ $1 == - ]]; }; }; do
        positionals+=("$1"); shift
    done
    source_file=${positionals[1]-}
    positional_count=${#positionals}
    if [[ $action == pack || $action == unpack ]]; then
        data_input=${positionals[1]-}; data_output=${positionals[2]-}; source_file=
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
                if [[ $action == compile || $action == debug ]]; then compiler_args+=("$@"); return; fi
                while (( $# )) && [[ $1 != -- ]]; do compiler_args+=("$1"); shift; done
                if (( $# )); then shift; runtime_args+=("$@"); fi
                return ;;
            --help) help_requested=1 ;;
            --version) version_requested=1 ;;
            --set-defaults) defaults_requested=1 ;;
            --export-settings|--export-settings=*|--import-settings|--import-settings=*)
                [[ -z $transfer_action ]] || fail 'select one settings transfer action'
                take_value "$@"; (( ! consumed )) || shift
                transfer_path=$value; transfer_action=${arg#--}; transfer_action=${transfer_action%%-*} ;;
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
            --save-relpath|--save-relpath=*|--save-test-relpath|--save-test-relpath=*)
                if [[ $arg == *=* ]]; then value=${arg#*=}
                elif (( $# )) && [[ $1 == 0 || $1 == 1 ]]; then value=$1; shift
                else value=1; fi
                [[ $value == 0 || $value == 1 ]] || fail "${arg%%=*} accepts 0 or 1"
                if [[ $arg == --save-test-relpath* ]]; then save_test_relpath=$value; test_relpath_given=1; layout_controls=1
                else save_relpath=$value; relpath_given=1; fi ;;
            --minimize|--minimize=*)
                if [[ $arg == *=* ]]; then minimize=${arg#*=}
                elif (( $# )) && [[ $1 == sequence || $1 == lines || $1 == cases ]]; then minimize=$1; shift
                else minimize=sequence; fi
                case "$minimize" in sequence|lines|cases) ;; *) fail '--minimize accepts sequence, lines or cases' ;; esac ;;
            --validator|--validator=*) take_value "$@"; (( ! consumed )) || shift; validator=$value ;;
            --doctor) doctor_requested=1 ;;
            --make-prettier|--make-prettier=*)
                if [[ $arg == *=* ]]; then prettier=${arg#*=}
                elif (( $# )) && [[ $1 == only || $1 == check || $1 == before ]]; then prettier=$1; shift
                else prettier=auto; fi
                case "$prettier" in auto|only|check|before) ;; *) fail '--make-prettier accepts before, only or check' ;; esac ;;
            --port|--port=*|--wait|--wait=*)
                take_value "$@"; (( ! consumed )) || shift
                companion_controls=1
                if [[ $arg == --port* ]]; then companion_port=$value; else companion_wait=$value; fi ;;
            --text) text_conversion=1; data_controls=1 ;;
            --overwrite) overwrite=1; data_controls=1 ;;
            --stop-on-failure) stop_on_failure=1 ;;
            --test-dir|--test-dir=*|--in-tmp|--in-tmp=*|--ans-tmp|--ans-tmp=*|--bundle-format|--bundle-format=*|--text-sep|--text-sep=*|--source|--source=*|--report-tests|--report-tests=*)
                take_value "$@"; (( ! consumed )) || shift
                case "$arg" in
                    --test-dir*) test_dir=$value; layout_controls=1 ;;
                    --in-tmp*) in_template=$value; layout_controls=1 ;;
                    --ans-tmp*) ans_template=$value; layout_controls=1 ;;
                    --bundle-format*) [[ $value == legacy || $value == counted ]] || fail '--bundle-format accepts legacy or counted'; bundle_format=$value; bundle_given=1 ;;
                    --text-sep*) text_separator=$value; text_conversion=1; data_controls=1 ;;
                    --source*) source_file=$value; source_given=1 ;;
                    --report-tests*) [[ $value == all || $value == failed ]] || fail '--report-tests accepts all or failed'; report_tests=$value; report_controls=1 ;;
                esac ;;
            --interpreter-arg|--interpreter-arg=*) take_value "$@"; (( ! consumed )) || shift; interpreter_args+=("$value") ;;
            --language|--language=*)
                take_value "$@"; (( ! consumed )) || shift
                case "$value" in c++|c|python|auto) language_choice=$value ;; *) fail '--language accepts c++, c, python or auto' ;; esac ;;
            --interpreter|--interpreter=*) take_value "$@"; (( ! consumed )) || shift; interpreter_choice=$value; interpreter_given=1 ;;

            --cph-ng|--cph-ng=*|--save-relpth|--save-relpth=*) fail 'use --save-relpath' ;;
            --workspace-name|--workspace-name=*) fail 'use --wsp-name=NAME' ;;
            --workspace-dir|--workspace-dir=*) fail 'use --wsp-dir=DIR' ;;
            --destination-dir|--destination-dir=*) fail 'use --dest-dir=DIR' ;;
            --timeout|--timeout=*) fail 'use --TLE=MS' ;;
            --memory-limit|--memory-limit=*) fail 'use --MLE=MiB' ;;
            --num-test|--num-test=*) fail 'use --test-iters=N' ;;
            --no-w=*|--show-command=*|--cin=*|--cout=*|--time=*|--memory=*|--help=*|--version=*|--set-defaults=*)
                fail "${arg%%=*} does not take a value" ;;
            --no-w) no_warnings=1 ;;
            --show-command) show_command=1 ;;
            --cin) console_in=1 ;;
            --cout) console_out=1 ;;
            --time) measure_time=1 ;;
            --memory) measure_memory=1 ;;
            -[ftm]##|-[ftm]##=*)
                # Inspect only a whole f/t/m cluster: native -fopenmp and
                # other compiler options pass through without reinterpretation.
                value=${arg%%=*}
                [[ $value != *t* ]] || measure_time=1
                [[ $value != *m* ]] || measure_memory=1
                if [[ $value == *f* ]]; then
                    [[ $value != *f*f* ]] || fail 'use -f only once'
                    (( ++f_count == 1 )) || fail 'use -f only once'
                    f_mode=$DEFAULT_F_MODE
                    if [[ $arg == *=* ]]; then
                        [[ ${arg#*=} == auto || ${arg#*=} == in || ${arg#*=} == out ]] || fail '-f accepts auto, in or out; omit its value for the saved action'
                        f_mode=${arg#*=}
                    elif (( $# )) && [[ $1 == auto || $1 == in || $1 == out ]]; then f_mode=$1; shift; fi
                    # File operands belong to automatic redirection, never to
                    # macro selection. -- cleanly ends these optional operands.
                    if [[ $f_mode == auto || $f_mode == in || $f_mode == out ]]; then
                        if [[ $f_mode != out ]] && (( $# )) && [[ $1 != -* ]]; then input_file=$1; shift; fi
                        if [[ $f_mode != in ]] && (( $# )) && [[ $1 != -* ]]; then result_file=$1; shift; fi
                    fi
                else [[ $arg != *=* ]] || fail '-t and -m do not take values'; fi ;;
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
            --test|--run|--run=*|--run-file|--run-file=*|--run-args|--run-arg=*) fail 'use test/run commands and -- argument boundaries; see --help' ;;
            -*)
                compiler_args+=("$arg")
                if compiler_operand "$arg" && (( $# )); then compiler_args+=("$1"); shift; fi ;;
            *) fail "unexpected argument: $arg; put program arguments after --" ;;
        esac
    done
    managed_count=${#compiler_args}
}


# Source: paths.zsh
# Resolve workspace routing once, for compilation or run --find.
# An explicit binary path skips this branch just like an explicit -o path.
resolve_workspace() {
    local requested
    if (( name_given )); then
        case "$workspace_name" in ''|.|..|*/*) fail 'workspace name must be one nonempty directory name' ;; esac
    fi
    if (( dir_given || ! name_given )); then
        requested=$workspace_dir
        case "$requested" in
            .|./|"$cwd"|"$cwd"/) workspace=$cwd ;;
            *)
                if [[ $requested != /* ]]; then requested="$cwd/$requested"; fi
                workspace=$(cd -q -P -- "$requested" 2>/dev/null && pwd -P) ||
                    fail "workspace directory is not accessible: $requested" 1 ;;
        esac
        if (( name_given )) && [[ ${workspace:t} != "$workspace_name" ]]; then
            fail "workspace name '$workspace_name' does not match directory '${workspace:t}'"
        fi
    else
        workspace=$cwd
        while [[ ${workspace:t} != "$workspace_name" ]]; do
            [[ $workspace != / ]] || fail "workspace folder not found: $workspace_name" 1
            workspace=${workspace:h}
        done
    fi
    workspace_prefix="${workspace%/}/" # Exactly one separator, also for '/'.
    [[ -n $destination && $destination != /* ]] || fail 'destination must be a nonempty relative path'
    case "/$destination/" in */../*) fail 'destination must not contain .. components' ;; esac
    output_dir="$workspace_prefix$destination"
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
    if [[ -n $fallback && -f $fallback ]]; then source_file=$fallback; return; fi
    (( ! ${#sources} )) || fail "cannot select $preferred source: provide FILE or create $fallback"
    # With no preferred-language source, accept a unique other-language source
    # or a unique conventional fallback. Never resolve ambiguity by glob order.
    sources=(./*.(cpp|cc|cxx|C|c|py)(N-.))
    if (( ${#sources} == 1 )); then source_file=${sources[1]#./}; return; fi
    for candidate in "$DEFAULT_SOURCE" "$C_SOURCE" "$PYTHON_SOURCE"; do
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
    if (( ! test_relpath_given )); then save_test_relpath=${MODE_SAVE_TEST_RELPATH[$profile]-${ACTION_SAVE_TEST_RELPATH[$key]-${ACTION_SAVE_TEST_RELPATH[$base]-${ACTION_SAVE_TEST_RELPATH[$parent]-0}}}}; fi
    if (( save_relpath && ! destination_given )) && [[ -z ${MODE_DEST_DIR[$profile]-}${ACTION_DEST_DIR[$key]-}${ACTION_DEST_DIR[$base]-}${ACTION_DEST_DIR[$parent]-} ]]; then
        destination=$DEFAULT_RELPATH_DESTINATION
    fi
}

# Omitted stress roles use a conventional stem, preferring the main language.
# An explicit saved filename still wins when it exists.
discover_role() {
    local requested=$1 stem=$2 preferred suffix
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
        *) fail 'invalid saved CPU policy; use --set-defaults' ;;
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
    if [[ $family == gcc ]]; then
        append_flags "${MODE_GCC[$profile]-}"
        if (( ! no_warnings )); then append_flags "${MODE_WARNINGS_GCC[$profile]-}"; fi
    else
        append_flags "${MODE_CLANG[$profile]-}"
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
        sidecar_protected+=("$cwd/real-out.txt")
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
    command_args=("$compiler" "$source_file" "${flags[@]}" "${compiler_args[@]}" "${profile_levels[@]}" -o "$stage/${target:t}")
    if (( show_command )); then printf '%q ' "${command_args[@]}" >&2; printf '\n' >&2; fi
    if [[ $action == compile || $action == test || $action == stress ]]; then "${command_args[@]}" >&2 || rc=$?
    else "${command_args[@]}" || rc=$?; fi
    (( rc == 0 )) || return $rc
    [[ -f $stage/${target:t} ]] || fail 'compiler produced no fresh output artifact' 1
    if [[ $action != compile ]]; then [[ -x $stage/${target:t} ]] || fail 'compiler output is not executable' 126; fi
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
history_location() {
    local scope=${workspace:-$cwd} state_root=${XDG_STATE_HOME:-$HOME/.local/state}/cp-run/history
    local character stored= digest= hi lo
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
        IFS= read -r -d $'\0' stored < "$directory/scope" || { history_warn; return 1; }
        [[ $stored == "$scope" ]] || { history_warn; return 1; }
    else
        # Exclusive creation resolves concurrent first use without replacing
        # an already claimed scope. NUL terminates paths containing newlines.
        (umask 077; setopt NO_CLOBBER; printf '%s\0' "$scope" > "$directory/scope") 2>/dev/null || {
            IFS= read -r -d $'\0' stored < "$directory/scope" || { history_warn; return 1; }
            [[ $stored == "$scope" ]] || { history_warn; return 1; }
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
    local marker= field
    [[ -f $history_directory/$1 && ! -L $history_directory/$1 ]] || fail "no last $1 in this workspace" 1
    {
        IFS= read -r -d $'\0' value || fail 'invalid history record' 1
        if [[ $1 == binary ]] && IFS= read -r -d $'\0' marker; then
            [[ $marker == CP_RUN_ARGV_V1 ]] || fail 'unsupported launch history record' 1
            while IFS= read -r -d $'\0' field; do
                (( ${#recalled_launch} < 256 )) || fail 'launch history has too many arguments' 1
                recalled_launch+=("$field")
            done
        fi
    } < "$history_directory/$1"
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
    local language=c++ primary_language=c++ interpreter= interpreter_choice=$DEFAULT_INTERPRETER language_choice=$DEFAULT_LANGUAGE
    local action=ordinary source_file= compiler_choice=$DEFAULT_COMPILER family= compiler= compiler_banner= profile=none
    local workspace_dir=$DEFAULT_WORKSPACE workspace_name= destination=$DEFAULT_DESTINATION workspace= workspace_prefix=
    local output= output_dir= output_name= output_abs= planned_source= planned_output= resolved_binary= auto_standard=
    local input_file=$DEFAULT_INPUT result_file=$DEFAULT_OUTPUT answer_file=$DEFAULT_ANSWER report_file=$DEFAULT_REPORT
    local brute_file=$DEFAULT_BRUTE generator_file=$DEFAULT_GENERATOR find_name= f_mode=none separator=$DEFAULT_SEPARATOR
    local timeout_ms=$DEFAULT_TIMEOUT memory_mib=$DEFAULT_MEMORY_LIMIT num_test= seed= python= cwd=$PWD
    local warmup=$DEFAULT_WARMUP average=$DEFAULT_AVERAGE time_unit=$DEFAULT_TIME_UNIT memory_unit=$DEFAULT_MEMORY_UNIT
    local transfer_action= transfer_path= history_directory= history_warning=0
    local value option_name arg index previous role base_profile=none temporary= current_profile previous_profile
    local -i argument_count=$# binary_mode=0 auto=0 dir_given=0 name_given=0 destination_given=0 output_given=0 save_relpath=0 std_seen=0
    local -i no_warnings=0 macro_file_io=0 show_command=0 measure_time=0 measure_memory=0
    local -i console_in=0 console_out=0 sep_given=0 help_requested=0 version_requested=0 defaults_requested=0 managed_count=0
    local test_dir=$DEFAULT_TEST_DIR in_template=$DEFAULT_INPUT_TEMPLATE ans_template=$DEFAULT_ANSWER_TEMPLATE
    local bundle_format=legacy bundle_stream= data_input= data_output= text_separator=$MANUAL_SEPARATOR report_tests=$DEFAULT_REPORT_TESTS
    local minimize= validator=
    local prettier= companion_port=$COMPANION_PORT companion_wait=$COMPANION_WAIT
    local -i doctor_requested=0 interpreter_given=0 compiler_given=0
    local -i data_controls=0 layout_controls=0 companion_controls=0 source_given=0 report_controls=0 bundle_given=0
    local -i overwrite=0 text_conversion=0 stop_on_failure=0
    local -i positional_count=0 mult=0 save_test_relpath=0 relpath_given=0 test_relpath_given=0
    local -i timeout_given=0 memory_given=0 measurement_controls=0
    local -a interpreter_args=() recalled_launch=() launch_args=() primary_launch=() original_compiler_args=() original_standards=()
    local -a compiler_args=() runtime_args=() cases=() sources=() artifacts=() protected_files=() build_indices=()
    local -A config=() compiler_paths=() compiler_banners=() standard_vocab=()
    local -a managed_standards=() supported_standards=()

    # One cleanup owner covers build staging and a console-input snapshot.
    # A normal exec replaces this process only after all temporary work is done.
    trap cleanup EXIT
    parse_cli "$@"
    if (( help_requested )); then show_help; return; fi
    if (( doctor_requested )); then
        config=(interpreter "$interpreter_choice" native_formatter "$NATIVE_FORMATTER" python_formatter "$PYTHON_FORMATTER")
        python_action doctor; return $?
    fi
    if [[ $prettier == only || $prettier == check || $prettier == auto && $action == ordinary && $positional_count == 0 ]]; then
        (( ! binary_mode && ! ${#compiler_args} && ! ${#runtime_args} && ! output_given )) || fail 'format-only action does not compile or run; provide a source file'
        [[ $profile == none || -n ${MODE_KIND[$profile]-} ]] || fail "profile not found: $profile"
        [[ -n $source_file ]] || select_source
        protected_files=("${source_file:A}")
        config=(prettier "$prettier" native_formatter "$NATIVE_FORMATTER" python_formatter "$PYTHON_FORMATTER")
        python_action format; return $?
    fi
    if [[ -n $transfer_action ]]; then
        [[ -z $source_file && ${#compiler_args} == 0 && ${#runtime_args} == 0 ]] &&
            (( argument_count <= 2 && ! defaults_requested && ! version_requested )) || fail 'use settings transfer on its own'
        embedded_python "$transfer_action" "$SCRIPT_PATH" "$transfer_path"; return $?
    fi
    if (( defaults_requested )); then
        (( argument_count == 1 )) || fail 'use --set-defaults on its own'
        embedded_python settings "$SCRIPT_PATH"; return $?
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
    (( ! text_conversion )) || [[ $action == pack || $action == unpack ]] || fail '--text/--text-sep require pack/unpack'
    (( ! data_controls )) || [[ $action == pack || $action == unpack || $action == companion ]] || fail 'import controls require pack/unpack/companion'
    (( ! layout_controls )) || (( mult )) || [[ $action == pack || $action == unpack || $action == companion ]] || fail 'layout options require mult/pack/unpack/companion'
    (( ! report_controls )) || [[ $action == test || $action == stress ]] || fail '--report-tests requires test/stress'
    (( ! source_given )) || [[ $action == pack || $action == unpack || $action == companion ]] || fail '--source is a data-operation anchor; use FILE'
    (( ! stop_on_failure )) || [[ $action == stress ]] || fail '--stop-on-failure requires stress'
    if (( bundle_given )); then [[ $action == test && $auto == 1 ]] || fail '--bundle-format requires test=auto'; fi
    if [[ $action == companion || $action == pack || $action == unpack ]]; then
        (( ! ${#compiler_args} && ! ${#runtime_args} && ! output_given && ! measure_time && ! measure_memory )) && [[ $f_mode == none && -z $prettier ]] || fail 'data operations cannot compile or run programs'
    fi
    # Cheap option conflicts precede file opens and all compiler discovery.
    [[ $profile == none || -n ${MODE_KIND[$profile]-} ]] || fail "profile not found: $profile; use --set-defaults"
    if [[ $profile != none && ${MODE_KIND[$profile]} == debug ]] && (( no_warnings )); then fail 'debug profile conflicts with --no-w'; fi
    if [[ $action == debug && ${MODE_KIND[$profile]} != debug ]]; then
        fail "profile '$profile' is a flags set; select it with --profile=$profile"
    fi
    if [[ $action == test || $action == stress ]]; then [[ $f_mode == none ]] || fail '-f is unavailable in test/stress'; fi
    if [[ $action == test || $action == stress ]]; then
        (( timeout_given )) || timeout_ms=$CHECK_TIMEOUT
        (( memory_given )) || memory_mib=$CHECK_MEMORY_LIMIT
    fi
    (( ! measurement_controls || measure_time || measure_memory )) || fail '--warm-up/--average require -t or -m'
    if [[ $action != test ]]; then (( ! console_in )) || fail '--cin is only available in test'; fi
    if [[ $action != test && $action != stress ]]; then
        (( ! console_out )) && [[ -z $num_test ]] || fail 'test/stress options require test or stress'
    fi
    [[ -z $seed || $action == stress ]] || fail '--seed requires stress'
    [[ -z $minimize && -z $validator || $action == stress ]] || fail 'counterexample reduction requires stress'
    [[ -z $validator || -n $minimize ]] || fail '--validator requires --minimize'
    if [[ $minimize == lines || $minimize == cases ]]; then [[ -n $validator ]] || fail 'this reduction strategy requires --validator'; fi
    if [[ -n $validator ]]; then validator=${validator:A}; [[ -f $validator && ( -x $validator || $validator == *.py ) ]] || fail 'validator must be executable or a Python script'; fi
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
    if [[ $action == compile ]]; then
        (( ! measure_time && ! measure_memory && ! ${#runtime_args} )) && [[ $f_mode != auto && $f_mode != in && $f_mode != out ]] || fail 'runtime options require an execution command'
    fi
    case "$f_mode" in none|auto|in|out) ;; macro) macro_file_io=1 ;; *) fail 'invalid saved -f mode; use --set-defaults' ;; esac
    [[ $DEFAULT_MACRO == [A-Za-z_][A-Za-z0-9_]# ]] || fail 'FILEO macro setting must be a C identifier'
    for option_name value in --TLE "$timeout_ms" --MLE "$memory_mib"; do
        [[ $value == inf ]] && continue
        [[ $value == <-> && ${#value} -le 12 ]] && (( 10#$value > 0 )) || fail "$option_name requires a positive integer (up to 12 digits) or inf"
    done
    cwd=$(pwd -P) || fail 'cannot resolve the current directory' 1
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
    if (( mult )) || [[ $action == companion || $action == pack || $action == unpack ]]; then
        resolve_workspace
    fi
    if [[ $action == companion ]]; then
        source_file=${source_file:-$DEFAULT_SOURCE}
        config=(source_anchor "${source_file:A}" workspace "$workspace" destination "$destination" test_dir "$test_dir"
                save_test_relpath "$save_test_relpath" in_template "$in_template" ans_template "$ans_template"
                overwrite "$overwrite" port "$companion_port" wait "$companion_wait" max_spool "$MAX_SPOOL_BYTES")
        protected_files=("${source_file:A}")
        python_action companion; return $?
    fi
    if [[ $action == pack || $action == unpack ]]; then
        if [[ -z $source_file ]]; then
            local -a anchors=(./*.(cpp|cc|cxx|C|c|py)(N-.))
            if (( ${#anchors} == 1 )); then source_file=${anchors[1]}
            else source_file=$DEFAULT_SOURCE; fi
        fi
        config=(operation "$action" workspace "$workspace" destination "$destination" test_dir "$test_dir"
                save_test_relpath "$save_test_relpath" default_input "$input_file" default_answer "$answer_file"
                bundle_stream "$bundle_stream" data_input "$data_input" data_output "$data_output"
                source_anchor "${source_file:A}" in_template "$in_template" ans_template "$ans_template"
                sep "$separator" text_sep "$text_separator" text_conversion "$text_conversion" overwrite "$overwrite" max_spool "$MAX_SPOOL_BYTES")
        protected_files=("${source_file:A}")
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
    output_abs=${artifacts[1]}
    config=(operation "$action" auto "$auto" mult "$mult" workspace "${workspace:-$cwd}" destination "$destination"
            test_dir "$test_dir" save_test_relpath "$save_test_relpath" source_anchor "${source_file:A}"
            in_template "$in_template" ans_template "$ans_template" bundle_format "$bundle_format"
            minimize "$minimize" validator "$validator" validator_interpreter "$interpreter_choice" minimize_attempts "$MINIMIZE_ATTEMPTS" minimize_seconds "$MINIMIZE_SECONDS"
            report_tests "$report_tests" stop_on_failure "$stop_on_failure" max_failures "$MAX_FAILURES" input "$input_file" answer "$answer_file" report "$report_file"
            actual "$cwd/real-out.txt" sep "$separator" cases "${(j:,:)cases}" num_test "$num_test"
            line_limit "$DEFAULT_LINE_LIMIT" cin "$console_in" cout "$console_out" executable "$output_abs"
            timeout_ms "$timeout_ms" memory_mib "$memory_mib" show_time "$measure_time" show_memory "$measure_memory"
            show_command "$show_command" seed "$seed" iterations "$DEFAULT_ITERATIONS" script "$SCRIPT_PATH"
            warmup "$warmup" average "$average" time_unit "$time_unit" memory_unit "$memory_unit"
            time_factor "$TIME_KILL_FACTOR" memory_factor "$MEMORY_KILL_FACTOR"
            max_line "$MAX_LINE_BYTES" max_check "$MAX_CHECK_BYTES" max_report "$MAX_REPORT_BYTES"
            report_lines "$MAX_REPORT_LINES" max_spool "$MAX_SPOOL_BYTES")
    if [[ -n $source_file ]]; then config[anchor_dir]="${source_file:A:h}"; else config[anchor_dir]=$cwd; fi
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
    if [[ -n $prettier ]]; then
        (( ! binary_mode )) || fail 'formatting needs source files'
        local -a protected_files=("${sources[@]}")
        config[prettier]=$prettier; config[native_formatter]=$NATIVE_FORMATTER; config[python_formatter]=$PYTHON_FORMATTER
        python_action format || return $?
        protected_files=("${sources[@]}" "${artifacts[@]}")
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
                if [[ $action == compile || $action == test || $action == stress ]]; then
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
                if (( ! compiler_given )); then compiler_choice=${LANGUAGE_COMPILERS[$language]-$DEFAULT_COMPILER}; fi
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
    if [[ $action == compile ]]; then printf '%s\n' "$output_abs"; return; fi
    if history_location; then config[history_binary]="$history_directory/binary"; fi
    if [[ $action == test || $action == stress ]]; then python_action "$action"; return $?; fi

    if (( show_command )) && [[ $f_mode == auto || $f_mode == in || $f_mode == out ]]; then
        printf '%q ' "${primary_launch[@]}" "${runtime_args[@]}" >&2
        if [[ $f_mode != out ]]; then printf '< %q ' "$input_file" >&2; fi
        if [[ $f_mode != in ]]; then printf '> %q' "$result_file" >&2; fi
        printf '\n' >&2
        config[show_command]=0; show_command=0
    fi
    # Open only requested streams. Native and observed paths inherit the same
    # descriptors; only redirected input is eligible for warm-up replay.
    if [[ $f_mode == auto || $f_mode == in ]]; then
        config[warmup_input]=$input_file
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
"""Repeated runs reuse one supervisor and expose one measured stdout only."""

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
        if warm.verdict in ('INTERRUPTED', 'TLE', 'MLE') or (config.get('operation') in ('test', 'stress') and warm.status):
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


def supervise(config):
    """Snapshot only input needing replay; opening/copying is outside child timing."""
    runner = _runner(config)
    argv = [*config.get('main_argv', [config['executable']]), *config.get('runtime_args', [])]
    observed = bool(config.get('show_time') or config.get('show_memory'))
    count = repetition_count(config.get('average', 1)) if observed else 1
    if count > 1 and os.isatty(0):
        raise CheckUsageError('repeated measurements need redirected input, not a terminal')
    with ExitStack() as stack:
        sink = stack.enter_context(open(os.devnull, 'wb'))
        no_input = stack.enter_context(open(os.devnull, 'rb'))
        replay = None
        replay_offset = 0
        if count > 1:
            source = stack.enter_context(os.fdopen(os.dup(0), 'rb'))
            if stat.S_ISREG(os.fstat(0).st_mode):
                replay = source; replay_offset = source.tell()
            else:
                replay = stack.enter_context(tempfile.TemporaryFile())
                maximum = positive_setting(config.get('max_spool', 268435456), 'spool limit')
                copied = 0
                while True:
                    block = source.read(65536)
                    if not block: break
                    copied += len(block)
                    if copied > maximum: raise CheckSetupError('replayed input exceeds spool byte limit')
                    replay.write(block)
        def launch(index):
            if replay is not None:
                replay.seek(replay_offset); incoming = replay
            elif index < 0:
                incoming = no_input
                if config.get('warmup_input'):
                    incoming = stack.enter_context(open(config['warmup_input'], 'rb'))
            else: incoming = None
            if index == 0 and config.get('show_command'):
                print(shlex.join(argv), file=sys.stderr, flush=True)
            runner.on_launch = (lambda: remember_launch(config)) if index >= 0 else None
            return runner.run(argv, stdin=incoming, stdout=None if index == 0 else sink,
                              stderr=sink if index < 0 else None, report=False)
        return run_series(runner, config, launch).status


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
text or captures stderr. The shell prepares executable paths before execution.
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
        reads = config.get("case_reads") if config.get("mult") else [config.get("input", "input.txt"), config.get("answer", "ans.txt")]
        reads = reads or []
        if len(reads) == 2 and _same_path(*reads):
            raise CheckUsageError("test input and answer must be different files")
        for path in reads:
            if not Path(path).is_file():
                raise CheckSetupError("test file not found or not regular: " + str(path))
            if any(_same_path(path, other) for other in protected):
                raise CheckUsageError("test data must not alias a source or executable: " + str(path))
    actual = Path("real-out.txt").absolute()
    # The fixed name is intentional; config cannot quietly change this role.
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
            'input': config.get('input', 'input.txt'), 'answer': config.get('answer', 'ans.txt')}
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
"""Restricted numbered templates and a shared, contained test-data writer."""

import re


def case_template(pattern, stem, number=None):
    """Only literal text, one {n}, and source-stem aliases are supported."""
    for alias in ("{filename-noExt}", "{file-name-no-ext}", "{filename-no-ext}"):
        pattern = pattern.replace(alias, "{stem}")
    if pattern.count("{n}") != 1:
        raise CheckUsageError("test template must contain exactly one {n}")
    rest = pattern.replace("{n}", "").replace("{stem}", "")
    if "{" in rest or "}" in rest:
        raise CheckUsageError("unknown template placeholder; use {n} and {stem}")
    if not stem or "/" in stem or stem in (".", ".."):
        raise CheckUsageError("invalid source stem for test template")
    value = pattern.replace("{stem}", stem)
    if number is not None:
        value = value.replace("{n}", str(number))
    if "\x00" in value or Path(value).is_absolute() or ".." in Path(value).parts:
        raise CheckUsageError("test template must stay inside its test directory")
    return value


def layout_root(config):
    """Artifact and data relative paths are independent, each appended once."""
    workspace = Path(config.get("workspace", ".")).resolve()
    relative = config.get("test_dir") or config.get("destination", ".")
    if Path(relative).is_absolute() or ".." in Path(relative).parts:
        raise CheckUsageError("test directory must be workspace-relative without ..")
    root = workspace / relative
    if config.get("save_test_relpath"):
        anchor = Path(config.get("source_anchor") or config.get("executable") or ".").absolute()
        parent = (
            Path(config["anchor_dir"])
            if config.get("anchor_dir")
            else anchor.parent
            if anchor.is_file() or anchor.suffix
            else anchor
        )
        try:
            subtree = parent.resolve().relative_to(workspace)
        except ValueError:
            raise CheckUsageError("test source must be inside the workspace") from None
        root = root / subtree
    try:
        root.resolve().relative_to(workspace)
    except ValueError:
        raise CheckUsageError("test directory escapes workspace") from None
    return root


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


def discover_cases(root, pattern, stem):
    """Discover sparse numerical IDs; never stop at the first missing file."""
    root = Path(root)
    template = case_template(pattern, stem)
    expression = re.compile(
        "^" + re.escape(Path(template).as_posix()).replace(r"\{n\}", r"([0-9]+)") + "$"
    )
    prefix = template.split("{n}", 1)[0]
    base = root / (Path(prefix) if prefix.endswith("/") else Path(prefix).parent)
    if not base.is_dir():
        raise CheckSetupError("test directory not found: " + str(base))
    result = {}
    candidates = base.rglob("*") if "/" in template[len(prefix) :] else base.iterdir()
    for path in candidates:
        match = expression.fullmatch(path.relative_to(root).as_posix())
        if not match:
            continue
        digits = match[1]
        if len(digits) > 12 or int(digits) < 1:
            raise CheckUsageError("test IDs must be positive integers")
        number = int(digits)
        if number in result:
            raise CheckUsageError("duplicate numerical test ID: " + digits)
        if len(result) >= 100000:
            raise CheckSetupError("test directory exceeds 100000 cases")
        target = contained_target(root, path.relative_to(root))
        if not target.is_file():
            raise CheckSetupError("test is not a regular file: " + str(target))
        result[number] = target
    return result


def mult_cases(config):
    root = layout_root(config)
    stem = Path(config.get("source_anchor") or config.get("executable", "main.cpp")).stem
    left = discover_cases(root, config.get("in_template", "./{n}.in"), stem)
    right = discover_cases(root, config.get("ans_template", "./{n}.ans"), stem)
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
"""Count-first separator bundles, with byte-exact manual conversion checks."""


def counted_cases(filename, separator):
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


def atomic_data_file(filename, payload, overwrite=False, protected=()):
    target = Path(filename).absolute()
    if target.is_symlink() or any(_same_path(target, p) for p in protected):
        raise CheckUsageError("bundle output aliases a protected file")
    write_test_files(target.parent, [(target.name, payload)], overwrite, protected)


def execute_bundle(config):
    """Both streams share the same codec; answers are never special-cased."""
    stream = config.get("bundle_stream")
    if stream not in ("in", "ans"):
        raise CheckUsageError("--pack/--unpack accepts in or ans")
    source, target = config.get("data_input"), config.get("data_output")
    default_file = (
        config.get("default_input", "input.txt")
        if stream == "in"
        else config.get("default_answer", "ans.txt")
    )
    bundle_file = str(Path(default_file).with_suffix(".bundle"))
    manual = bool(config.get("text_conversion"))

    def directory(explicit):
        if not explicit:
            return layout_root(config)
        root = Path(explicit).absolute()
        if config.get("save_test_relpath"):
            workspace = Path(config.get("workspace", ".")).resolve()
            parent = Path(config.get("source_anchor", "main.cpp")).absolute().parent.resolve()
            try:
                root = root / parent.relative_to(workspace)
            except ValueError:
                raise CheckUsageError("test source must be inside workspace") from None
        return root

    if config["operation"] == "pack":
        source = (source or default_file) if manual else directory(source)
        target = target or bundle_file
    else:
        source = source or bundle_file
        target = (target or default_file) if manual else directory(target)
    separator = decode_separator(config.get("sep", r"\n\x1e\n"))
    text_separator = decode_separator(config.get("text_sep", r"\n###\n"))
    manual = bool(config.get("text_conversion"))
    maximum = positive_setting(config.get("max_spool", 268435456), "conversion byte limit")
    overwrite = bool(config.get("overwrite"))
    protected = (
        [*config.get("protected", []), source]
        if Path(source).is_file()
        else config.get("protected", [])
    )
    if config["operation"] == "pack":
        if manual:
            cases = counted_cases(source, text_separator)
            if sum(case.length for case in cases) > maximum:
                raise CheckSetupError("bundle exceeds conversion byte limit")
            records = [slice_bytes(case, maximum) for case in cases]
        else:
            stem = Path(config.get("source_anchor", "main.cpp")).stem
            key = "in_template" if stream == "in" else "ans_template"
            pattern = config.get(key, "./{n}." + stream)
            found = discover_cases(source, pattern, stem)
            if not found:
                raise CheckUsageError("no matching tests to pack")
            ordered = sorted(found)
            records = []
            total = 0
            for number in ordered:
                case = index_cases(found[number])[0]
                total += case.length
                if total > maximum:
                    raise CheckSetupError("bundle exceeds conversion byte limit")
                records.append(slice_bytes(case, maximum))
            protected = [*protected, *found.values()]
            if ordered != list(range(1, len(ordered) + 1)):
                print(
                    "cp-run: packed IDs {} as 1..{}".format(ordered, len(ordered)), file=sys.stderr
                )
        payload = encode_bundle(records, separator, maximum)
        atomic_data_file(target, payload, overwrite, protected)
    else:
        cases = counted_cases(source, separator)
        if sum(case.length for case in cases) > maximum:
            raise CheckSetupError("bundle exceeds conversion byte limit")
        records = [slice_bytes(case, maximum) for case in cases]
        if manual:
            atomic_data_file(
                target, encode_bundle(records, text_separator, maximum), overwrite, protected
            )
        else:
            stem = Path(config.get("source_anchor", "main.cpp")).stem
            key = "in_template" if stream == "in" else "ans_template"
            pattern = config.get(key, "./{n}." + stream)
            entries = [
                (case_template(pattern, stem, i), record) for i, record in enumerate(records, 1)
            ]
            write_test_files(target, entries, overwrite, protected)
    print(
        "cp-run: {} {}: {} cases".format(config["operation"], stream, len(records)), file=sys.stderr
    )
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


def _failure_details(report, incoming, actual, answer, comparison, display_limit):
    report.detail_remaining = report.max_details
    display_limit = report.display_lines
    if comparison.reason: report.emit('INCOMPLETE: ' + comparison.reason)
    _section(report, "input", incoming, display_limit=display_limit)
    _section(report, "real-out.txt", actual, comparison.actual_different, display_limit)
    _section(report, "ans", answer, comparison.answer_different, display_limit)
    for left, right in comparison.missing_rows:
        if left is None:
            report.detail("  ! real-out.txt:— | <missing line>; ans:{}".format(right))
        if right is None:
            report.detail("  ! ans:— | <missing line>; real-out.txt:{}".format(left))


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
        _failure_details(report, incoming, actual, answer, comparison, report.display_lines)
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
                    incoming, answer, actual = (directory / name for name in ('input.txt', 'ans.txt', 'actual.txt'))
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
            os.replace(combined, config['actual'])
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
    for filename in ("input.txt", "ans.txt", "real-out.txt"):
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
                  str(destination / "input.txt"), str(destination / "ans.txt"), str(destination / "replay-report.txt"),
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
        incoming, answer, actual = (directory / name for name in ('input.txt', 'ans.txt', 'real-out.txt'))
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
    original = Path(directory) / "input.txt"
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
    stem = Path(config.get("source_anchor", "main.cpp")).stem
    entries = []
    for number, (incoming, answer) in enumerate(samples, 1):
        entries.extend(
            (
                (case_template(config.get("in_template", "./{n}.in"), stem, number), incoming),
                (case_template(config.get("ans_template", "./{n}.ans"), stem, number), answer),
            )
        )
    root = layout_root(config)
    # Detect stale samples: never leave a previous problem's extra tests behind
    # and accidentally run them as part of a new import.
    for key, suffix in (("in_template", "in"), ("ans_template", "ans")):
        pattern = config.get(key, "./{n}." + suffix)
        if root.is_dir():
            try:
                old = discover_cases(root, pattern, stem)
            except CheckSetupError:
                old = {}
            if set(old) - set(range(1, len(samples) + 1)):
                raise CheckUsageError(
                    "existing extra samples would remain; choose a clean test directory"
                )
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


# Source: integrations.py
"""Optional formatting and feature-oriented dependency diagnostics."""


def execute_format(config):
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
                "optional formatter not found: " + tool + "; see README installation"
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


SETTINGS_BEGIN = '# CP_RUN_SETTINGS_BEGIN'
SETTINGS_END = '# CP_RUN_SETTINGS_END'
SETTINGS_GROUPS = {
    'common': 'MODE_FLAGS', 'gcc': 'MODE_GCC', 'clang': 'MODE_CLANG',
    'libstdc++': 'MODE_LIBSTDCXX', 'libc++': 'MODE_LIBCPP',
    'warnings-gcc': 'MODE_WARNINGS_GCC', 'warnings-clang': 'MODE_WARNINGS_CLANG',
    'cpython': 'MODE_CPYTHON', 'pypy': 'MODE_PYPY',
}
# Keep metadata in the same copy/reset/delete transaction as compiler flags.
PROFILE_KEYS = ('MODE_KIND', 'MODE_CPU', 'MODE_DEST_DIR', 'MODE_SAVE_RELPATH',
                'MODE_SAVE_TEST_RELPATH', *SETTINGS_GROUPS.values())
PROFILE_DEFAULTS = {'MODE_KIND': 'flags', 'MODE_CPU': 'default'}

# These defaults mirror the native block. A regression test checks equality so
# reset cannot quietly diverge from a freshly downloaded script.
FACTORY_SETTINGS = {
    'DEFAULT_COMPILER': 'GCC', 'DEFAULT_STANDARD': 'auto',
    'DEFAULT_LANGUAGE': 'c++', 'LANGUAGE_COMPILERS': {},
    'DEFAULT_SOURCE': 'main.cpp', 'DEFAULT_TIMEOUT': 'inf',
    'DEFAULT_MEMORY_LIMIT': 'inf', 'DEFAULT_INPUT': 'input.txt',
    'DEFAULT_OUTPUT': 'output.txt', 'DEFAULT_ANSWER': 'ans.txt',
    'DEFAULT_REPORT': 'test_out', 'DEFAULT_SEPARATOR': r'\n\x1e\n',
    'MANUAL_SEPARATOR': r'\n###\n', 'DEFAULT_INTERPRETER': 'pypy3',
    'C_STANDARD': 'auto', 'C_SOURCE': 'main.c', 'PYTHON_SOURCE': 'main.py',
    'PYTHON_FLAGS': [], 'MODE_CPYTHON': {'debug': '-X dev -W default', 'extra': '-X dev -W error'},
    'MODE_PYPY': {'debug': '-W default -X track-resources', 'extra': '-W error -X track-resources'},
    'ACTION_DEST_DIR': {'test-mult': 'tests'}, 'ACTION_SAVE_RELPATH': {},
    'ACTION_SAVE_TEST_RELPATH': {}, 'MODE_DEST_DIR': {},
    'MODE_SAVE_RELPATH': {}, 'MODE_SAVE_TEST_RELPATH': {},
    'DEFAULT_INPUT_TEMPLATE': './{n}.in', 'DEFAULT_ANSWER_TEMPLATE': './{n}.ans',
    'DEFAULT_TEST_DIR': '', 'NATIVE_FORMATTER': 'clang-format', 'PYTHON_FORMATTER': 'ruff', 'DEFAULT_REPORT_TESTS': 'all',
    'COMPANION_PORT': '27122', 'COMPANION_WAIT': '120',
    'MINIMIZE_ATTEMPTS': '200', 'MINIMIZE_SECONDS': '30', 'MAX_FAILURES': '10',
    'DEFAULT_LINE_LIMIT': '10000', 'DEFAULT_F_MODE': 'macro',
    'DEFAULT_MACRO': 'FILEO', 'DEFAULT_WORKSPACE': '.',
    'DEFAULT_DESTINATION': '.', 'DEFAULT_RELPATH_DESTINATION': '.',
    'DEFAULT_BRUTE': 'brute.cpp', 'DEFAULT_GENERATOR': 'gen.cpp',
    'DEFAULT_ITERATIONS': '1000', 'DEFAULT_SEED': '4',
    'CHECK_TIMEOUT': '1500', 'CHECK_MEMORY_LIMIT': '256',
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
             '# Managed by --set-defaults; ordinary launches read these native values directly.']
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


def flag_units(words):
    """Keep known option/operand pairs intact during toggle operations."""
    paired = {'-I', '-L', '-l', '-D', '-U', '-isystem', '-iquote', '-include',
              '-imacros', '-isysroot', '--sysroot', '-target', '--target',
              '-arch', '-B', '-X', '-W', '--jit', '-Xlinker', '-Xclang', '-Xpreprocessor', '-mllvm'}
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


def _settings_unit_key(unit):
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


def _settings_change_flags(current, command):
    """Return a new list; a malformed edit cannot partially change settings."""
    action = 'toggle'
    for prefix in ('add ', 'remove '):
        if command.startswith(prefix):
            action, command = prefix.strip(), command[len(prefix):]
            break
    units = flag_units(current)
    for unit in flag_units(shlex.split(command)):
        key = _settings_unit_key(unit)
        matches = [item for item in units if _settings_unit_key(item) == key]
        units = [item for item in units if _settings_unit_key(item) != key]
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
    if '/' in value or value in ('.', '..') or not value.endswith(('.cpp', '.cc', '.cxx', '.C', '.c', '.py')):
        raise ValueError('use a C/C++/Python filename without directory components')
    return value


def _settings_destination(value):
    """Match routing's lexical rules; physical containment is checked at use."""
    if Path(value).is_absolute() or '..' in Path(value).parts:
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
        changed = [] if command == 'clear' else _settings_change_flags(current, command)
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


def _settings_profile_preview(editor, name):
    """Expand platform groups on request; the everyday menu stays compact."""
    print('Configured combinations; compiler/library support is checked at build time:')
    print('CPU: {}; native selection is resolved at build time.'.format(
        editor.data['MODE_CPU'].get(name, 'default')))
    if not any(editor.data[key].get(name, '') for key in ('MODE_LIBSTDCXX', 'MODE_LIBCPP')):
        print('No standard-library-specific flags in this profile.')
    for family in ('gcc', 'clang'):
        base = editor.data['WARNINGS_GCC' if family == 'gcc' else 'WARNINGS_CLANG']
        for library in ('libstdc++', 'libc++'):
            groups = ('common', family, library, 'warnings-' + family)
            words = list(editor.data['DEFAULT_FLAGS']) + list(base)
            for group in groups:
                words.extend(shlex.split(editor.data[SETTINGS_GROUPS[group]].get(name, '')))
            print('  {} + {}: {}'.format(family, library, shlex.join(words) or '(none)'))


def _settings_profile_menu(editor, name):
    while name in editor.data['MODE_NAMES']:
        print('\nProfile {} ({})'.format(name, editor.data['MODE_KIND'][name]))
        print('  Native common: ' + (editor.data['MODE_FLAGS'].get(name, '') or '(none)'))
        print('  CPU: ' + editor.data['MODE_CPU'].get(name, 'default'))
        print('  Compiler/library adaptations are retained; Python groups are under advanced.')
        choice = editor.ask('profile> [flags / preview / advanced / kind / cpu / delete / back]: ')
        if choice is None:
            continue
        if choice in ('', 'back'):
            return
        if choice == 'flags':
            _settings_flags(editor, 'MODE_FLAGS', name)
        elif choice == 'preview':
            _settings_profile_preview(editor, name)
        elif choice == 'advanced':
            groups = list(SETTINGS_GROUPS)
            for i, group in enumerate(groups, 1):
                print('  {}. {}: {}'.format(i, group, editor.data[SETTINGS_GROUPS[group]].get(name, '') or '(none)'))
            group = editor.ask('Group number/name, or back: ')
            if group is None:
                continue
            if group.isdecimal() and 1 <= int(group) <= len(groups):
                group = groups[int(group) - 1]
            if group in SETTINGS_GROUPS:
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
                reserved = {'compile', 'run', 'test', 'stress', 'tr', 'sr', 'none', 'plain'}
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
        raise ValueError('script changed while editing; reopen --set-defaults')
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
            raise ValueError('script changed while editing; reopen --set-defaults')
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
        print('  {}: {} -> {}'.format(key, repr(before), repr(after)))
    print('Preferred omitted-source language: ' + editor.data['DEFAULT_LANGUAGE'])
    # Preview each actual backend instead of showing a misleading C++ command
    # when Python or C is the user's preferred language.
    for language, standard_key in (('c++', 'DEFAULT_STANDARD'), ('c', 'C_STANDARD')):
        compiler = editor.data['LANGUAGE_COMPILERS'].get(language, editor.data['DEFAULT_COMPILER'])
        warnings = editor.data['WARNINGS_GCC' if compiler == 'GCC' else 'WARNINGS_CLANG']
        standard = editor.data[standard_key]
        if standard.isdecimal(): standard = language + standard
        dialect = '[newest supported ISO ' + language + ']' if standard == 'auto' else '-std=' + standard
        print('Result ({}): --compiler={} {} {}'.format(language, compiler, dialect,
              shlex.join(editor.data['DEFAULT_FLAGS'] + warnings)))
    print('Result (python): ' + shlex.join([editor.data['DEFAULT_INTERPRETER'], *editor.data['PYTHON_FLAGS']]))
    answer = input('Write these changes to this script? [y/N]: ').strip().lower()
    if answer not in ('y', 'yes'):
        print('Cancelled; nothing saved.')
        return 0
    save_settings(filename, original, editor.data)
    print('Saved in {}. No configuration file was created.'.format(filename))
    return 0


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
        ('DEFAULT_INPUT', 'Input file', None), ('DEFAULT_ANSWER', 'Answer file', None),
        ('DEFAULT_OUTPUT', 'Redirected program output', None),
        ('DEFAULT_REPORT', 'Test/stress report', None),
        ('DEFAULT_F_MODE', 'Bare -f action', _settings_choice('macro', 'auto', 'in', 'out')),
        ('DEFAULT_MACRO', '-f macro identifier', _settings_macro),
        ('DEFAULT_RELPATH_DESTINATION', 'Destination with --save-relpath', _settings_destination),
    ]
    checks = [
        ('DEFAULT_TIMEOUT', 'Time budget in ms', lambda v: _settings_positive(v, True)),
        ('DEFAULT_MEMORY_LIMIT', 'Memory budget in MiB', lambda v: _settings_positive(v, True)),
        ('DEFAULT_SEPARATOR', r'Auto-test separator (visible \n)', lambda v: (_settings_separator(v), v)[1]),
        ('DEFAULT_LINE_LIMIT', 'Comparison row budget', _settings_positive),
        ('CHECK_TIMEOUT', 'Test/stress time budget in ms', lambda v: _settings_positive(v, True)),
        ('CHECK_MEMORY_LIMIT', 'Test/stress memory budget in MiB', lambda v: _settings_positive(v, True)),
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
            print('\ncp-run 1.1 defaults — changes stay pending until save')
            print('  1. Build: {} / {} / {}'.format(editor.data['DEFAULT_COMPILER'],
                editor.data['DEFAULT_STANDARD'], shlex.join(editor.data['DEFAULT_FLAGS']) or '(no flags)'))
            print('  2. Files: {} / {} / {}'.format(editor.data['DEFAULT_SOURCE'],
                editor.data['DEFAULT_INPUT'], editor.data['DEFAULT_ANSWER']))
            print('  3. Warnings\n  4. Checking & limits: {} ms / {} MiB'.format(
                editor.data['DEFAULT_TIMEOUT'], editor.data['DEFAULT_MEMORY_LIMIT']))
            print('  5. Profiles: {}\n  6. Stress: up to {} cases, seed {}'.format(
                ', '.join(editor.data['MODE_NAMES']) or '(none)', editor.data['DEFAULT_ITERATIONS'],
                editor.data['DEFAULT_SEED']))
            try:
                print('  7. Measurements\n  8. Languages & tools\n  9. Test files & integrations\n  10. Action/profile routing\n  export FILE / import FILE: portable preferences (data only)')
                choice = editor.ask('defaults> [1–10 / export FILE / import FILE / show / undo / reset / help / save / cancel]: ')
                if choice is None:
                    continue
                if choice == '1':
                    _settings_build(editor)
                elif choice == '2':
                    _settings_fields(editor, 'Files (real-out.txt is fixed)', files)
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
                        ('DEFAULT_INPUT_TEMPLATE', 'Input template', lambda v: (case_template(v, 'main', 1), v)[1]),
                        ('DEFAULT_ANSWER_TEMPLATE', 'Answer template', lambda v: (case_template(v, 'main', 1), v)[1]),
                        ('DEFAULT_TEST_DIR', 'Data directory (inherit uses destination)', lambda v: '' if v == 'inherit' else _settings_destination(v)),
                        ('MANUAL_SEPARATOR', 'Manual separator', lambda v: (_settings_separator(v), v)[1]),
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
                    for key, value in updated.items():
                        if editor.data.get(key) != value: print('{}: {} -> {}'.format(key, repr(editor.data.get(key)), repr(value)))
                    editor.replace(updated)
                    print('Imported into pending edits; save to apply.')
                elif choice == 'show':
                    for key, value in editor.data.items():
                        print('{}: {}'.format(key, repr(value)))
                else:
                    print('Choose a displayed number; help explains editing.')
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
    with editor.scope(['DEFAULT_LANGUAGE', 'LANGUAGE_COMPILERS', 'DEFAULT_INTERPRETER', 'C_SOURCE', 'PYTHON_SOURCE', 'C_STANDARD', 'NATIVE_FORMATTER', 'PYTHON_FORMATTER', 'PYTHON_FLAGS']):
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
    with editor.scope(['ACTION_DEST_DIR', 'ACTION_SAVE_RELPATH', 'ACTION_SAVE_TEST_RELPATH', 'MODE_DEST_DIR', 'MODE_SAVE_RELPATH', 'MODE_SAVE_TEST_RELPATH']):
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
        fields = {'dest-dir': prefix + 'DEST_DIR', 'save-relpath': prefix + 'SAVE_RELPATH',
                  'save-test-relpath': prefix + 'SAVE_TEST_RELPATH'}
        while True:
            for label, key in fields.items(): print('  {}: {}'.format(label, editor.data[key].get(name, '(inherit)')))
            command = editor.ask('routing {}> [FIELD VALUE / inherit FIELD / back]: '.format(name))
            if command in ('', 'back'): break
            if command is None: continue
            words = shlex.split(command)
            if len(words) != 2: print('Example: dest-dir build/debug; or inherit dest-dir'); continue
            inherit = words[0] == 'inherit'
            field = words[1] if inherit else words[0]
            if field not in fields: print('Use dest-dir, save-relpath or save-test-relpath.'); continue
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
    if not isinstance(values, dict) or set(values) - set(FACTORY_SETTINGS):
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
    data['DEFAULT_COMPILER'] = _settings_compiler(data['DEFAULT_COMPILER'])
    _settings_standard(data['DEFAULT_STANDARD'])
    _settings_choice('c++', 'c', 'python', 'auto')(data['DEFAULT_LANGUAGE'])
    if set(data['LANGUAGE_COMPILERS']) - {'c', 'c++'}:
        raise ValueError('compiler overrides support c and c++ only; use DEFAULT_INTERPRETER for Python')
    data['LANGUAGE_COMPILERS'] = {key: _settings_compiler(value) for key, value in data['LANGUAGE_COMPILERS'].items()}
    if data['C_STANDARD'] != 'auto' and not re.fullmatch(r'(?:[0-9]+|(?:gnu|c)[0-9][A-Za-z0-9]*|iso9899:[0-9]+)', data['C_STANDARD']): raise ValueError('invalid C standard')
    for key in ('DEFAULT_INPUT_TEMPLATE', 'DEFAULT_ANSWER_TEMPLATE'): case_template(data[key], 'main', 1)
    _settings_filename(data['DEFAULT_SOURCE'])
    for key in ('DEFAULT_BRUTE', 'DEFAULT_GENERATOR'):
        _settings_filename(data[key])
    for key in ('DEFAULT_TIMEOUT', 'DEFAULT_MEMORY_LIMIT', 'CHECK_TIMEOUT', 'CHECK_MEMORY_LIMIT'):
        data[key] = _settings_positive(data[key], True)
    for key in ('DEFAULT_LINE_LIMIT', 'DEFAULT_ITERATIONS', 'MAX_LINE_BYTES', 'MAX_CHECK_BYTES',
                'MAX_REPORT_BYTES', 'MAX_REPORT_LINES', 'MAX_SPOOL_BYTES'):
        data[key] = _settings_positive(data[key])
    _settings_seed(data['DEFAULT_SEED'])
    _settings_separator(data['DEFAULT_SEPARATOR'])
    _settings_macro(data['DEFAULT_MACRO'])
    _settings_choice('macro', 'auto', 'in', 'out')(data['DEFAULT_F_MODE'])
    _settings_choice('0', '1')(data['DEFAULT_WARMUP'])
    for key in ('TIME_KILL_FACTOR', 'MEMORY_KILL_FACTOR'):
        _factor(data[key])
    data['DEFAULT_AVERAGE'] = str(repetition_count(data['DEFAULT_AVERAGE']))
    _settings_choice('s', 'ms')(data['DEFAULT_TIME_UNIT'])
    _settings_choice('B', 'KB', 'KiB', 'MB', 'MiB')(data['DEFAULT_MEMORY_UNIT'])
    for key in ('DEFAULT_DESTINATION', 'DEFAULT_RELPATH_DESTINATION'):
        if not data[key]: raise ValueError('empty destination')
        _settings_destination(data[key])
    for key in ('DEFAULT_WORKSPACE', 'DEFAULT_INPUT', 'DEFAULT_OUTPUT', 'DEFAULT_ANSWER', 'DEFAULT_REPORT'):
        if not data[key]: raise ValueError('empty setting: ' + key)
    # Optional map entries inherit; an explicit zero remains a real override.
    actions = {'ordinary', 'compile', 'debug', 'run', 'test', 'test-auto', 'test-mult', 'stress', 'companion'}
    for key in ('ACTION_DEST_DIR', 'ACTION_SAVE_RELPATH', 'ACTION_SAVE_TEST_RELPATH'):
        if set(data[key]) - actions: raise ValueError('unknown action in ' + key)
    for key in ('MODE_DEST_DIR', 'MODE_SAVE_RELPATH', 'MODE_SAVE_TEST_RELPATH'):
        data[key] = {name: value for name, value in data[key].items() if value != ''}
    for key in ('ACTION_DEST_DIR', 'MODE_DEST_DIR'):
        for value in data[key].values():
            if not value: raise ValueError('empty destination override')
            _settings_destination(value)
    for key in ('ACTION_SAVE_RELPATH', 'ACTION_SAVE_TEST_RELPATH', 'MODE_SAVE_RELPATH', 'MODE_SAVE_TEST_RELPATH'):
        for value in data[key].values(): _settings_choice('0', '1')(value)
    for key in ('DEFAULT_TEST_DIR',):
        if data[key]: _settings_destination(data[key])
    for key in ('C_SOURCE', 'PYTHON_SOURCE'): _settings_filename(data[key])
    _settings_separator(data['MANUAL_SEPARATOR'])
    _settings_choice('all', 'failed')(data['DEFAULT_REPORT_TESTS'])
    for key in ('COMPANION_PORT', 'COMPANION_WAIT', 'MINIMIZE_ATTEMPTS', 'MINIMIZE_SECONDS', 'MAX_FAILURES'):
        _settings_positive(data[key])
    if int(data['COMPANION_PORT']) > 65535: raise ValueError('port must be 1..65535')
    if not data['DEFAULT_INTERPRETER']: raise ValueError('empty interpreter')
    flag_units(data['PYTHON_FLAGS'])
    names = data['MODE_NAMES']
    for key in PROFILE_KEYS:
        if key not in values: data[key] = {name: value for name, value in data[key].items() if name in names}
    if len(set(names)) != len(names): raise ValueError('duplicate profile name')
    reserved = {'companion', 'compile', 'run', 'test', 'stress', 'tr', 'sr', 'none', 'plain'}
    for name in names:
        if not re.fullmatch(r'[A-Za-z][A-Za-z0-9_-]{0,31}', name) or name in reserved:
            raise ValueError('invalid profile name: ' + name)
        if data['MODE_KIND'].get(name) not in ('debug', 'flags'):
            raise ValueError('invalid profile kind: ' + name)
        if data['MODE_CPU'].get(name, 'default') not in ('default', 'native'):
            raise ValueError('invalid profile CPU policy: ' + name)
    for key in PROFILE_KEYS:
        if set(data[key]) - set(names): raise ValueError('unknown profile in ' + key)
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
    record = {'format': 'cp-run-settings', 'schema': 2, 'settings': data}
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
            or record['schema'] not in (1, 2)):
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
    for key in ('auto', 'cin', 'cout', 'show_time', 'show_memory', 'show_command', 'warmup', 'mult', 'save_test_relpath', 'overwrite', 'text_conversion', 'stop_on_failure'):
        config[key] = config.get(key, '0') == '1'
    config['cases'] = [int(value) for value in config.get('cases', '').split(',') if value]
    for key in ('num_test', 'seed'):
        if config.get(key, '') == '':
            config.pop(key, None)
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
