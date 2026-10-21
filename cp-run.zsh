#!/bin/zsh -f
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 cp-run contributors
# One C++ source, one selected output, and an optional run. Requires zsh 5.9.

# Start from native, predictable options instead of inheriting interactive
# customizations. Expected failures are checked explicitly, without ERR_EXIT.
emulate -LR zsh
setopt NO_UNSET PIPE_FAIL EXTENDED_GLOB
unsetopt ALIASES
typeset -r PROGRAM=cp-run VERSION=1.0
typeset -r SCRIPT_PATH=${0:A} # Settings follow the real script when invoked through a symlink.

# CP_RUN_SETTINGS_BEGIN
# Managed by --set-defaults; ordinary launches read these native values directly.
typeset -g DEFAULT_COMPILER=GCC
typeset -g DEFAULT_STANDARD=auto
typeset -g DEFAULT_SOURCE=main.cpp
typeset -g DEFAULT_TIMEOUT=inf
typeset -g DEFAULT_MEMORY_LIMIT=inf
typeset -g DEFAULT_INPUT=input.txt
typeset -g DEFAULT_OUTPUT=output.txt
typeset -g DEFAULT_ANSWER=ans.txt
typeset -g DEFAULT_REPORT=test_out
typeset -g DEFAULT_SEPARATOR='\n\n'
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
typeset -gA MODE_FLAGS=(debug '-O2 -g2 -fsanitize=address,undefined -fsanitize=float-cast-overflow -fno-sanitize-recover=all -fno-omit-frame-pointer -DLOCAL' extra '-Og -g2 -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer -fno-optimize-sibling-calls -DLOCAL' pragma '-O3 -funroll-loops' pragma-fast '-funroll-loops -fno-stack-protector -ffast-math' pragma-native '-funroll-loops -fno-stack-protector -ffast-math')
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
Usage: cp-run [FILE] [OPTION]... [-- COMPILER-ARG... [-- PROGRAM-ARG...]]
       cp-run compile|debug[=PROFILE] [FILE] [OPTION]... [-- COMPILER-ARG...]
       cp-run run [BINARY] [OPTION]... [-- PROGRAM-ARG...]
       cp-run test[=auto] [run] [CASE...] [FILE [IN [ANS [REPORT]]]] [OPTION]...
       cp-run stress [run] [MAIN [BRUTE [GEN]]] [OPTION]...
       cp-run tr [IN [ANS [REPORT]]] [OPTION]... [-- PROGRAM-ARG...]
       cp-run sr BRUTE GEN [OPTION]... [-- PROGRAM-ARG...]
       cp-run --help|--version|--set-defaults
       cp-run --export-settings=FILE | --import-settings=FILE

Build, debug and check C++ with GCC or Clang. FILE defaults to the only local
.cpp, otherwise main.cpp. Requires zsh 5.9; advanced features need Python 3.9+.

Commands:
  compile                 Build only; print the absolute executable path
  debug[=PROFILE]          Build/run a debug profile (default debug; extra is deeper)
  run                     Run an existing binary without compilation
  test[=auto]             Compare input.txt against ans.txt; auto splits cases
  stress                  Compare MAIN and BRUTE on inputs from GEN
  test run, stress run    Check existing binaries instead of building sources
  tr, sr                  test run - / stress run -; reuse the last primary binary

Build and files:
  --compiler=NAME         GCC/gcc/g++ (default), clang/clang++; any position
  -std=VALUE              C++ number/native alias; default newest advertised mode
  --profile=NAME          Saved debug/flags set, including pragma[-fast|-native]
  --no-w                  Omit generated warnings; native -w remains separate
  -o PATH, -oPATH         Exact compiler output; overrides all routing
  -f, --file-io            Define FILEO (saved action and macro are editable)
  -f=auto [IN [OUT]]      Redirect input/output; defaults input.txt/output.txt
  --wsp-dir=DIR           Workspace path; default ./ when absent
  --wsp-name=NAME         Search ancestors, or check the explicit workspace
  --dest-dir=DIR          Workspace-relative binary directory; default ./
  --save-relpath          Preserve the source subtree beneath destination
  --find=NAME             Find an omitted binary FILE; one .out is optional

Checking and resources:
  --sep=TEXT              Auto-test literal separator; default '\n\n'
  --test-iters=N          Maximum selected tests / stress iterations
  --seed=N                Stress starting seed, unsigned 64-bit; default 4
  --cin                   Read test input and answer from framed stdin
  --cout                  Print the test/stress report instead of saving it
  -t, --time              Elapsed program time in milliseconds
  -m, --memory            Peak resident memory in KiB
  --warm-up[=0|1]         Hidden warm-up with -t/-m; default 1, bare means 1
  --average[=N]           N runs: median time / maximum RSS; default 1
  --time-unit=s|ms        Time display; default ms
  --memory-unit=UNIT      B, KB, KiB, MB or MiB; default KiB
  --TLE=MS                Time budget: test/stress 1500, other commands inf
  --MLE=MiB               RSS budget: test/stress 256, other commands inf
  --show-command          Print escaped execution commands on stderr

Information:
  --set-defaults          Interactive settings saved inside this script
  --export-settings=FILE  Save portable preferences (data-only JSON)
  --import-settings=FILE  Validate/apply an export; no compiler required
  --help                  Show this help without querying a compiler
  --version               Show cp-run and selected compiler versions

Values accept '=' or a separate operand: --wsp-dir DIR, -std 23, -f auto.
Required values cannot be empty or omitted. Short f/t/m flags combine: -ftm.
-f is unavailable in test/stress, which manage their own input and output.
Unknown options reach the compiler. -- starts compiler/program tails as shown
above; run and binary checks have one program tail; compile/debug have one
compiler tail. A plain flags set is selected only through --profile.
Compiler/program stderr is direct. --show-command alone displays commands.
With -t/-m, warm once and measure N runs; stdout is exposed exactly once.
--average alone uses its saved count; --average=0 means one measured run.
FILE - reuses the last source/binary in this workspace; ./- is literal.
Measurements exclude compilation/setup. Limits fail above the nominal budget;
continuing programs are killed at the saved multiplier (default x2).
See CLI.md and TESTING.md in the documentation for details and ready examples.

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
            --output|--std|--stdlib) ;;
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
            compile|run|stress) action=$1; shift ;;
            debug|debug=*)
                action=debug; value=${1#debug}; value=${value#=}
                select_profile "${value:-debug}"; shift ;;
            test|test=|test=auto) action=test; [[ $1 != test=auto ]] || auto=1; shift ;;
            test=*) fail 'test supports normal mode or test=auto; test=manual was removed' ;;
        esac
    fi
    if [[ $action == run ]]; then binary_mode=1; fi
    if [[ $action == test || $action == stress ]] && (( $# )) && [[ $1 == run ]]; then
        binary_mode=1; shift
    fi

    # Numbered case selectors occupy their own prefix, never source operands.
    if [[ $action == test ]] && (( auto )); then
        while (( $# )) && [[ $1 == <-> || $1 == -<-> ]]; do cases+=("$1"); shift; done
    elif [[ $action == test ]] && (( $# )) && [[ $1 == <-> || $1 == -<-> ]]; then
        fail 'case numbers require test=auto; prefix a numeric filename with ./'
    fi
    case "$action" in test) slots=4 ;; stress) slots=3 ;; esac
    while (( $# && ${#positionals} < slots )) && { [[ $1 != -* ]] || { (( ! ${#positionals} )) && [[ $1 == - ]]; }; }; do
        positionals+=("$1"); shift
    done
    source_file=${positionals[1]-}
    positional_count=${#positionals}
    if [[ $action == test ]]; then
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
                    --compiler*) compiler_choice=$value ;;
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
            --save-relpath) save_relpath=1 ;;
            --cph-ng|--cph-ng=*|--save-relpth|--save-relpth=*) fail 'use --save-relpath' ;;
            --workspace-name|--workspace-name=*) fail 'use --wsp-name=NAME' ;;
            --workspace-dir|--workspace-dir=*) fail 'use --wsp-dir=DIR' ;;
            --destination-dir|--destination-dir=*) fail 'use --dest-dir=DIR' ;;
            --timeout|--timeout=*) fail 'use --TLE=MS' ;;
            --memory-limit|--memory-limit=*) fail 'use --MLE=MiB' ;;
            --num-test|--num-test=*) fail 'use --test-iters=N' ;;
            --save-relpath=*|--no-w=*|--show-command=*|--cin=*|--cout=*|--time=*|--memory=*|--help=*|--version=*|--set-defaults=*)
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
                        [[ ${arg#*=} == auto ]] || fail '-f accepts only auto; omit its value to define the file-I/O macro'
                        f_mode=auto
                    elif (( $# )) && [[ $1 == auto ]]; then f_mode=auto; shift; fi
                    # File operands belong to automatic redirection, never to
                    # macro selection. -- cleanly ends these optional operands.
                    if [[ $f_mode == auto ]]; then
                        if (( $# )) && [[ $1 != -* ]]; then input_file=$1; shift; fi
                        if (( $# )) && [[ $1 != -* ]]; then result_file=$1; shift; fi
                    fi
                else [[ $arg != *=* ]] || fail '-t and -m do not take values'; fi ;;
            -o|--output|--output=*) take_value "$@"; (( ! consumed )) || shift; output=$value; output_given=1 ;;
            -o?*) output=${arg#-o}; output_given=1 ;;
            -std|-std=*|--std|--std=*)
                take_value "$@"; (( ! consumed )) || shift
                [[ $value != <-> ]] || value="c++$value"
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
            [[ ! -f $candidate || ! -x $candidate ]] || found+=("$candidate")
        done
        (( ${#found} )) || fail "binary not found: $find_name" 1
        (( ${#found} == 1 )) || fail "ambiguous binary: $find_name; provide an explicit path"
        requested=${found[1]}
    fi
    [[ -f $requested ]] || fail "binary not found: $requested" 1
    [[ -x $requested ]] || fail "binary is not executable: $requested" 126
    resolved_binary=$requested
}

# Resolve plans before probing compilers or touching test data. The compiler
# helpers use zsh's dynamic local scope; their arrays never leak between roles.
# Omitted source selection is nonrecursive and uses regular files only.
select_source() {
    local -a sources=(./*.cpp(N-.))
    if (( ${#sources} == 1 )); then source_file=${sources[1]#./}
    elif [[ -f $DEFAULT_SOURCE ]]; then source_file=$DEFAULT_SOURCE
    else fail "cannot select a source: found ${#sources} .cpp files and no $DEFAULT_SOURCE"; fi
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
    local candidate directory major best=-1 best_path= detected_family=
    if [[ -n ${CXX:-} ]]; then
        compiler=$CXX               # One executable; flags belong in argv.
    elif [[ $family == clang ]]; then
        compiler=clang++
    else
        candidate=$(whence -p -- g++ 2>/dev/null)
        if [[ -n $candidate ]] && identify_compiler "$candidate" && [[ $detected_family == gcc ]]; then
            compiler=$candidate; return
        fi
        # Native path is an array tied to PATH. Read it; never use 'path' as
        # a scratch variable. (N) makes an unmatched driver glob an empty list.
        for directory in "${path[@]}"; do
            directory=${directory:-.}
            for candidate in "$directory"/g++-<->(N); do
                [[ -f $candidate && -x $candidate ]] || continue
                major=${candidate:t}; major=${major#g++-}; major=${major##0#}; major=${major:-0}
                (( ${#major} <= 3 )) || continue
                if (( major > best )) && identify_compiler "$candidate" && [[ $detected_family == gcc ]]; then
                    best=$major; best_path=$candidate
                fi
            done
        done
        [[ -n $best_path ]] || fail 'GNU g++ not found; set CXX or select --compiler=clang++' 127
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
        listing=$(LC_ALL=C "$compiler" --help=c++) || fail 'cannot query compiler standards' 1
    else
        listing=$(LC_ALL=C "$compiler" -std=__cp_run_probe__ -fsyntax-only -x c++ /dev/null 2>&1)
    fi
    # Work per line: removing a wildcard prefix from a 60 KiB GCC help
    # listing is needlessly expensive in zsh. Each small line scans once.
    for line in "${(@f)listing}"; do
        while [[ $line =~ '(^|[^[:alnum:]_+])((gnu|c)[+][+][[:alnum:]]+)' ]]; do
            candidate=$match[2]
            line=${line#*"$candidate"}
            supported_standards+=("$candidate")
        done
    done
    (( ${#supported_standards} )) || fail 'cannot discover supported C++ standards' 1
}

validate_standards() {
    discover_standards
    local standard
    for standard in "${managed_standards[@]}"; do
        (( ${supported_standards[(Ie)$standard]} )) || fail "unsupported C++ standard '$standard' for $compiler; supported: ${(j:, :)supported_standards}"
    done
}

detect_standard() {
    local candidate suffix year ordinal best=-1 selected=
    if [[ -n $auto_standard ]]; then flags+=("-std=$auto_standard"); return; fi
    discover_standards
    for candidate in "${supported_standards[@]}"; do
            [[ $candidate == c++* ]] || continue
            suffix=${candidate#c++}
            case "$suffix" in
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
    [[ -n $selected ]] || fail 'cannot discover supported C++ standards; specify -std=VALUE' 1
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
    if "$compiler" "$candidate" -Werror -x c++ -S /dev/null -o /dev/null >/dev/null 2>&1; then
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
            if [[ $value == <-> ]]; then value="c++$value"; fi
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
    if [[ -n ${MODE_LIBSTDCXX[$profile]-}${MODE_LIBCPP[$profile]-} ]]; then detect_library || return $?; fi
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
    elif [[ $f_mode == auto ]]; then sidecar_protected+=("$input_file" "$result_file"); fi
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
    [[ -f $history_directory/$1 && ! -L $history_directory/$1 ]] &&
        IFS= read -r -d $'\0' value < "$history_directory/$1" || fail "no last $1 in this workspace" 1
    [[ -n $value && -f $value && -r $value ]] || fail "last $1 is missing or unreadable: $value" 1
    [[ $1 != binary || -x $value ]] || fail "last binary is no longer executable: $value" 126
}

history_write() {
    history_location || return 0
    local temporary="$history_directory/.$1.$$.${RANDOM}${RANDOM}" target="$history_directory/$1"
    (umask 077; setopt NO_CLOBBER; printf '%s\0' "$2" > "$temporary" && zf_mv -f -- "$temporary" "$target") 2>/dev/null || {
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
    local -i positional_count=0
    local -i timeout_given=0 memory_given=0 measurement_controls=0
    local -a compiler_args=() runtime_args=() cases=() sources=() artifacts=() protected_files=() build_indices=()
    local -A config=()
    local -a managed_standards=() supported_standards=()

    # One cleanup owner covers build staging and a console-input snapshot.
    # A normal exec replaces this process only after all temporary work is done.
    trap cleanup EXIT
    parse_cli "$@"
    if (( help_requested )); then show_help; return; fi
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
    if (( version_requested )); then printf '%s %s\n' "$PROGRAM" "$VERSION"; resolve_compiler; "$compiler" --version; return $?; fi

    # Cheap option conflicts precede file opens and all compiler discovery.
    [[ $profile == none || -n ${MODE_KIND[$profile]-} ]] || fail "profile not found: $profile; use --set-defaults"
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
        (( ! console_out && ! sep_given )) && [[ -z $num_test ]] || fail 'test/stress options require test or stress'
    fi
    [[ -z $seed || $action == stress ]] || fail '--seed requires stress'
    # Select routing defaults after parsing so an explicit destination wins
    # in either option order. Exact -o paths still bypass routing entirely.
    if (( save_relpath && ! destination_given )); then destination=$DEFAULT_RELPATH_DESTINATION; fi
    if [[ $action == stress ]]; then
        seed=${seed:-$DEFAULT_SEED}
        # Compare equal-width decimal strings: zsh arithmetic is signed, while
        # generator seeds cover all 64 unsigned bits. No Python/probe is needed.
        [[ $seed == [0-9]## && ${#seed} -le 20 ]] &&
            [[ ${#seed} -lt 20 || $seed < 18446744073709551616 ]] || fail '--seed must be an unsigned 64-bit integer'
    fi
    if [[ $action == stress ]]; then (( ! sep_given )) || fail '--sep is only available in test=auto'; fi
    if [[ $action == test ]] && (( ! auto && sep_given )); then fail '--sep requires test=auto'; fi
    if (( binary_mode )); then
        [[ $profile == none && $f_mode != macro ]] && (( ! ${#compiler_args} && ! output_given )) || fail 'binary execution cannot use compilation options'
    elif [[ -n $find_name ]]; then fail '--find requires run, test run or stress run'; fi
    if [[ $action == compile ]]; then
        (( ! measure_time && ! measure_memory && ! ${#runtime_args} )) && [[ $f_mode != auto ]] || fail 'runtime options require an execution command'
    fi
    case "$f_mode" in none|auto) ;; macro) macro_file_io=1 ;; *) fail 'invalid saved -f mode; use --set-defaults' ;; esac
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
    if (( binary_mode )); then
        resolve_binary "$source_file"; artifacts+=("$resolved_binary"); protected_files+=("$resolved_binary")
        if [[ $action == stress ]]; then
            (( positional_count == 3 )) || fail 'stress run requires explicit BRUTE and GEN binary paths'
            resolve_binary "$brute_file"; artifacts+=("$resolved_binary"); protected_files+=("$resolved_binary")
            resolve_binary "$generator_file"; artifacts+=("$resolved_binary"); protected_files+=("$resolved_binary")
        fi
    else
        [[ -n $source_file ]] || select_source
        plan_artifact "$source_file" "$output" "$output_given"
        sources+=("$planned_source"); artifacts+=("$planned_output")
        if [[ $action == stress ]]; then
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
    config=(operation "$action" auto "$auto" input "$input_file" answer "$answer_file" report "$report_file"
            actual "$cwd/real-out.txt" sep "$separator" cases "${(j:,:)cases}" num_test "$num_test"
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
    elif [[ $f_mode == auto ]]; then
        for value in "${protected_files[@]}" "$input_file"; do
            [[ ${result_file:A} != ${value:A} && ! $result_file -ef $value ]] || fail 'redirected output would overwrite an input, source or binary' 1
        done
        for value in "${artifacts[@]}"; do [[ ${value:A} != ${input_file:A} && ! $value -ef $input_file ]] || fail 'binary output would overwrite runtime input' 1; done
    fi
    if (( ! binary_mode )); then
        resolve_compiler
        if (( ! std_seen )) && [[ $DEFAULT_STANDARD != auto ]]; then
            value=$DEFAULT_STANDARD; [[ $value != <-> ]] || value="c++$value"
            managed_standards+=("$value")
        fi
        if (( ${#managed_standards} )); then validate_standards; fi
        config[compiler_info]="$compiler_banner"
        base_profile=$profile
        for (( index=1; index<=${#sources}; ++index )); do
            (( build_indices[index] == index )) || continue
            profile=$base_profile; (( index == 1 )) || profile=none
            build_artifact "${sources[index]}" "${artifacts[index]}" "$profile" || return $?
        done
        profile=$base_profile
        history_write source "${sources[1]}"
    fi
    if [[ $action == compile ]]; then printf '%s\n' "$output_abs"; return; fi
    if history_location; then config[history_binary]="$history_directory/binary"; fi
    if [[ $action == test || $action == stress ]]; then python_action "$action"; return $?; fi

    # Measurements alone activate repetition; finite budgets without metrics
    # still execute once. Auto-input warm-up uses an independent file handle.
    if [[ $f_mode == auto ]]; then config[warmup_input]=$input_file; fi
    if (( measure_time || measure_memory )) || [[ $timeout_ms != inf || $memory_mib != inf ]]; then
        if [[ $f_mode == auto ]]; then
            if (( show_command )); then
                printf '%q ' "$output_abs" "${runtime_args[@]}" >&2
                printf '< %q > %q\n' "$input_file" "$result_file" >&2
                config[show_command]=0 # Parent owns the inherited redirection display.
            fi
            python_action supervise < "$input_file" > "$result_file"
        else python_action supervise; fi
        return $?
    fi
    if (( show_command )); then
        printf '%q ' "$output_abs" "${runtime_args[@]}" >&2
        if [[ $f_mode == auto ]]; then printf '< %q > %q' "$input_file" "$result_file" >&2; fi
        printf '\n' >&2
    fi
    if [[ $f_mode == auto ]]; then
        { history_write binary "$output_abs"; "$output_abs" "${runtime_args[@]}"; } < "$input_file" > "$result_file"
        return $?
    fi
    history_write binary "$output_abs"
    cleanup                          # exec will not run the shell's EXIT trap.
    exec -- "$output_abs" "${runtime_args[@]}"
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
            signalling = True
            try:
                # Keep the leader unreaped through this short check+kill
                # section, so its PID cannot become another group's ID.
                if outcome is None:
                    try:
                        os.killpg(pid, signum)
                    except ProcessLookupError:
                        pass
            finally:
                signalling = False

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
    observed = bool(config.get('show_time') or config.get('show_memory'))
    count = repetition_count(config.get('average', 1)) if observed else 1
    if observed and config.get('warmup'):
        warm = launch(-1)
        if warm.verdict in ('INTERRUPTED', 'TLE', 'MLE'):
            runner.diagnostic(warm, label)
            return warm
    durations, peak, result = [], 0, None
    for index in range(count):
        result = launch(index)
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
    runner.display(result, label, len(durations))
    return result


def supervise(config):
    """Snapshot only input needing replay; opening/copying is outside child timing."""
    runner = _runner(config)
    argv = [config['executable'], *config.get('runtime_args', [])]
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
    with open(os.devnull, 'wb') as sink:
        def launch(index):
            target = outgoing if index == 0 else hidden
            if index >= 0: _show_run(config, argv, incoming, target)
            runner.on_launch = (lambda: remember_launch(config)) if index >= 0 else None
            with open(incoming, 'rb') as stdin, open(target, 'wb') as stdout:
                result = runner.run(argv, stdin=stdin, stdout=stdout,
                                    stderr=sink if index < 0 else None, report=False)
            if index > 0 and result.status: shutil.copyfile(hidden, outgoing)
            return result
        def validate(index):
            target = outgoing if index == 0 else hidden
            comparison = compare_case(target, answer, config)
            comparisons[:] = [comparison]
            if not comparison.equal:
                if index > 0: shutil.copyfile(hidden, outgoing)
                return 'INCOMPLETE' if comparison.incomplete else 'WA'
            return None
        result = run_series(runner, config, launch, validate, label)
    if not Path(outgoing).exists() and hidden.exists(): shutil.copyfile(hidden, outgoing)
    hidden.unlink(missing_ok=True)
    comparison = comparisons[-1] if comparisons else None
    if result.status and result.verdict not in ('WA', 'INCOMPLETE', 'INTERRUPTED'):
        comparison = compare_case(outgoing, answer, config)
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
    text = str(value).replace(r"\n", "\n")
    allowed = "\n #=_.:+-abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
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


def index_cases(path, separator=None):
    """Index nonoverlapping delimiters across chunks; drop one terminal delimiter."""
    path = str(Path(path).resolve())
    if not Path(path).is_file(): raise CheckSetupError('test file not found or not regular: ' + path)
    if separator is None: return [CaseSlice(path, 0, Path(path).stat().st_size)]
    ranges, pending, base, start = [], b'', 0, 0
    with open(path, 'rb') as stream:
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
    if start < size or not ranges: ranges.append(CaseSlice(path, start, size - start))
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
        reads = [config.get("input", "input.txt"), config.get("answer", "ans.txt")]
        if _same_path(*reads):
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
    # Count mismatch takes priority over selection notices, output inspection
    # and compilation. No report or stdout artifact has been opened yet.
    paths = _console_paths(config) if config.get('cin') else {
        'input': config.get('input', 'input.txt'), 'answer': config.get('answer', 'ans.txt')}
    auto = bool(config.get('auto'))
    inputs = index_cases(paths['input'], separator if auto else None)
    answers = index_cases(paths['answer'], separator if auto else None)
    if len(inputs) != len(answers):
        raise CheckUsageError("test count mismatch: input has {} cases; answer has {}".format(len(inputs), len(answers)))
    requested = config.get("cases", [])
    if requested and not auto:
        raise CheckUsageError("case numbers require test=auto")
    selected, zero = [], False
    for value in requested:
        try:
            number = int(value)
        except (ValueError, TypeError):
            raise CheckUsageError("test case numbers must be integers") from None
        if number == 0:
            number, zero = 1, True
        if not 1 <= number <= len(inputs):
            raise CheckUsageError("test number {} is outside 1..{}".format(number, len(inputs)))
        if number not in selected:
            selected.append(number)
    selected = selected or list(range(1, len(inputs) + 1))
    if maximum is not None:
        selected = selected[:maximum]
    _validate_paths(config)
    return CheckPlan(inputs, answers, selected, separator, line_limit, zero)


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


class Protocol:
    """Keep report commits atomic and preserve a copy for stress failure bundles."""

    def __init__(self, config):
        self.max_line = positive_setting(config.get('max_line', 1048576), 'row byte limit')
        self.max_details = positive_setting(config.get('max_report', 262144), 'report byte limit')
        self.display_lines = positive_setting(config.get('report_lines', 10000), 'report row limit')
        self.detail_remaining = self.max_details
        self.console = bool(config.get("cout"))
        self.destination = Path(config.get("report", "test_out"))
        directory = self.destination.parent if not self.console else Path.cwd()
        handle = tempfile.NamedTemporaryFile(mode="w+", encoding="utf-8", dir=directory,
                                             prefix=".cp-run-report-", delete=False)
        self.stream, self.path = handle, Path(handle.name)

    def emit(self, text=""):
        self.stream.write(text + "\n")
        if self.console:
            print(text, flush=True)

    def detail(self, text):
        """Count encoded diagnostics, not source bytes that can expand on escaping."""
        size = len((text + '\n').encode('utf-8'))
        if size > self.detail_remaining:
            if self.detail_remaining:
                self.emit('  ... diagnostic byte limit reached; raw data retained')
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




# Source: checking.py
"""Execute selected sample cases using shared process/comparison services."""

def _runner(config):
    return Runner(timeout_ms=str(config.get("timeout_ms", "inf")),
                  memory_mib=str(config.get("memory_mib", "inf")),
                  show_time=bool(config.get("show_time")),
                  show_memory=bool(config.get("show_memory")), show_command=False,
                  time_factor=config.get('time_factor', '2'), memory_factor=config.get('memory_factor', '2'),
                  time_unit=config.get('time_unit', 'ms'), memory_unit=config.get('memory_unit', 'KiB'))


def _show_run(config, argv, incoming, outgoing):
    if config.get("show_command"):
        print("{} < {} > {}".format(shlex.join([str(x) for x in argv]),
                                    shlex.quote(str(incoming)), shlex.quote(str(outgoing))),
              file=sys.stderr, flush=True)


def _run_files(runner, config, argv, incoming, outgoing, label):
    _show_run(config, argv, incoming, outgoing)
    with open(incoming, "rb") as stdin, open(outgoing, "wb") as stdout:
        return runner.run([str(x) for x in argv], stdin=stdin, stdout=stdout, label=label)


def _publish_actual(source, destination):
    """Replace the latest stress stdout only after its complete copy succeeds."""
    target = Path(destination)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=target.parent, prefix=".cp-run-output-", delete=False) as output:
            temporary = Path(output.name)
            with open(source, "rb") as incoming:
                shutil.copyfileobj(incoming, output)
        os.replace(temporary, target)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def _aggregate(verdicts):
    for verdict, status in verdicts:
        if verdict == "INTERRUPTED":
            return status
    if any(verdict == "INCOMPLETE" for verdict, _ in verdicts):
        return 4
    for name, status in (("TLE", 124), ("MLE", 125)):
        if any(verdict == name for verdict, _ in verdicts):
            return status
    for verdict, status in verdicts:
        if verdict not in ("OK", "WA"):
            return status or 1
    return 3 if any(verdict == "WA" for verdict, _ in verdicts) else 0


def execute_test(config):
    """Run selected cases with one supervisor and continue candidate failures."""
    plan = _load_plan(config)
    if not config.get("executable"):
        raise CheckUsageError("test execution needs an executable")
    runner = _runner(config)
    argv = [config["executable"], *config.get("runtime_args", [])]
    verdicts, executed = [], 0
    with check_lock(), tempfile.TemporaryDirectory(prefix=".cp-run-test-", dir=".") as temporary:
        directory = Path(temporary)
        report = Protocol(config)
        combined = directory / "combined.stdout"
        try:
            if plan.zero_notice:
                print("cp-run: tests use 1-based indices; using 1 instead of 0", file=sys.stderr)
            report.emit("cp-run test: selected {} of {} cases".format(len(plan.selected), len(plan.inputs)))
            with open(combined, "wb") as all_output:
                for position, number in enumerate(plan.selected):
                    incoming, answer, actual = (directory / name for name in ("input.txt", "ans.txt", "actual.txt"))
                    plan.inputs[number - 1].copy_to(incoming); plan.answers[number - 1].copy_to(answer)
                    result, comparison = run_candidate(runner, config, argv, incoming, actual, answer, 'test {}'.format(number))
                    executed += 1
                    if position and config.get("auto"):
                        all_output.write(plan.separator)
                    with open(actual, "rb") as stream:
                        shutil.copyfileobj(stream, all_output)
                    if result.verdict == "INTERRUPTED":
                        verdict = "INTERRUPTED"
                    else:
                        comparison = comparison or compare_case(actual, answer, config)
                        verdict = result.verdict if result.status else ("OK" if comparison.equal else "WA")
                        if comparison.incomplete:
                            verdict = "INCOMPLETE"
                    status = 4 if verdict == "INCOMPLETE" else (3 if verdict == "WA" else result.status)
                    verdicts.append((verdict, status))
                    report.emit("Test {}: {}{}".format(number, verdict,
                                " (status {})".format(result.status) if result.status else ""))
                    if verdict != "OK" and comparison is not None:
                        _failure_details(report, incoming, actual, answer, comparison, plan.line_limit)
                    if verdict == "INTERRUPTED":
                        report.emit("Execution interrupted; partial stdout retained in real-out.txt")
                    if verdict == "INCOMPLETE":
                        report.emit("INCOMPLETE: unchecked output remains; no PASS verdict")
                    if result.verdict == "INTERRUPTED":
                        break
            status = _aggregate(verdicts)
            summary = "{}: {} selected cases executed; {} failed".format(
                "PASS" if status == 0 else "INCOMPLETE" if status == 4 else "FAIL",
                executed,
                sum(verdict != "OK" for verdict, _ in verdicts))
            report.emit(summary)
            if not config.get("cout"):
                print("cp-run: " + summary + "; report: " + str(config.get("report", "test_out")), file=sys.stderr)
            os.replace(combined, config["actual"])
            report.finish()
            return status
        except BaseException:
            report.abort()
            raise




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
    if config.get('show_time') or config.get('show_memory'):
        boundary = replay.index('--')
        replay[boundary:boundary] = [flag for enabled, flag in (
            (config.get('show_time'), '-t'), (config.get('show_memory'), '-m')) if enabled] + [
            '--average=' + str(config.get('average', 1)), '--warm-up=' + str(int(bool(config.get('warmup'))))]
    manifest = {"seed": seed, "iteration": iteration, "verdict": verdict,
                "commands": {"main": [config["executable"], *config.get("runtime_args", [])],
                             "brute": [config["brute"]], "generator": [config["generator"], str(seed)]},
                "limits": {"timeout_ms": config.get("timeout_ms", "inf"), "memory_mib": config.get("memory_mib", "inf")},
                "measurement": {key: config.get(key) for key in ('warmup', 'average', 'time_factor', 'memory_factor')},
                "results": results, "sha256": files, "replay_argv": replay,
                "compiler": config.get("compiler_info")}
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
    """Generate once, feed identical bytes to both programs, stop on first failure."""
    plan = _prepare_check(config)
    for key in ("executable", "brute", "generator"):
        if not config.get(key):
            raise CheckUsageError("stress execution needs " + key)
    runner = _runner(config)
    count = positive_setting(config.get("num_test") or config.get("iterations", 1000), "stress iterations")
    # The CLI supplies its saved value; direct callers share the factory seed.
    start = int(config["seed"]) if config.get("seed") is not None else 4
    main_argv = [config["executable"], *config.get("runtime_args", [])]
    with check_lock(), tempfile.TemporaryDirectory(prefix=".cp-run-stress-", dir=".") as temporary:
        directory, report = Path(temporary), Protocol(config)
        incoming, answer, actual = (directory / name for name in ("input.txt", "ans.txt", "real-out.txt"))
        seed, iteration, results = start, 0, {}
        try:
            report.emit("cp-run stress: start seed {}; maximum {} iterations".format(start, count))
            if not config.get("cout"):
                print("cp-run: stress start seed {}".format(start), file=sys.stderr)
            status = 0
            for iteration in range(1, count + 1):
                seed = (start + iteration - 1) % 2**64
                results = {}
                # Failed generator/reference phases must not borrow payloads
                # from a previous successful iteration in their saved bundle.
                answer.unlink(missing_ok=True)
                actual.unlink(missing_ok=True)
                with open(incoming, "wb") as stream, open(os.devnull, "rb") as no_input:
                    command = [config["generator"], str(seed)]
                    if config.get("show_command"):
                        print(shlex.join(command) + " > " + shlex.quote(str(incoming)), file=sys.stderr)
                    generated = runner.run(command, stdin=no_input, stdout=stream, label="generator {}".format(iteration))
                results["generator"] = {"status": generated.status, "elapsed_ns": generated.elapsed_ns, "peak_bytes": generated.peak_bytes}
                if generated.status:
                    verdict = "INTERRUPTED" if generated.verdict == "INTERRUPTED" else "GENERATOR_ERROR"
                    status = generated.status
                    report.emit("Iteration {}: {} (status {}; seed {})".format(iteration, verdict, status, seed))
                    _bundle(config, report, directory, seed, iteration, verdict, results); break
                reference = _run_files(runner, config, [config["brute"]], incoming, answer, "reference {}".format(iteration))
                results["reference"] = {"status": reference.status, "elapsed_ns": reference.elapsed_ns, "peak_bytes": reference.peak_bytes}
                if reference.status:
                    verdict = "INTERRUPTED" if reference.verdict == "INTERRUPTED" else "ORACLE_ERROR"
                    status = reference.status
                    report.emit("Iteration {}: {} (status {}; seed {})".format(iteration, verdict, status, seed))
                    _bundle(config, report, directory, seed, iteration, verdict, results); break
                result, comparison = run_candidate(runner, config, main_argv, incoming, actual, answer, 'candidate {}'.format(iteration))
                results["candidate"] = {"status": result.status, "elapsed_ns": result.elapsed_ns, "peak_bytes": result.peak_bytes}
                _publish_actual(actual, config["actual"])
                if result.verdict == "INTERRUPTED":
                    verdict, status = "INTERRUPTED", result.status
                    report.emit("Iteration {}: INTERRUPTED (seed {}); partial stdout retained".format(iteration, seed))
                    _bundle(config, report, directory, seed, iteration, verdict, results)
                    break
                comparison = comparison or compare_case(actual, answer, config)
                verdict = result.verdict if result.status else ("OK" if comparison.equal else "WA")
                if comparison.incomplete:
                    verdict = "INCOMPLETE"
                status = 4 if verdict == "INCOMPLETE" else 3 if verdict == "WA" else result.status
                report.emit("Iteration {}: {} (seed {})".format(iteration, verdict, seed))
                if status:
                    _failure_details(report, incoming, actual, answer, comparison, plan.line_limit)
                    _bundle(config, report, directory, seed, iteration, verdict, results)
                    break
            summary = ("No difference in {} generated cases".format(iteration) if status == 0
                       else "INCOMPLETE" if status == 4 else "Stress stopped at iteration {}".format(iteration))
            report.emit(summary)
            if not config.get("cout"):
                print("cp-run: " + summary + "; report: " + str(config.get("report", "test_out")), file=sys.stderr)
            report.finish()
            return status
        except KeyboardInterrupt:
            report.emit("INTERRUPTED at iteration {} (seed {})".format(iteration, seed))
            if incoming.exists():
                _bundle(config, report, directory, seed, iteration, "INTERRUPTED", results)
            report.finish()
            return 130
        except BaseException:
            report.abort()
            raise


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
}
# Keep metadata in the same copy/reset/delete transaction as compiler flags.
PROFILE_KEYS = ('MODE_KIND', 'MODE_CPU', *SETTINGS_GROUPS.values())
PROFILE_DEFAULTS = {'MODE_KIND': 'flags', 'MODE_CPU': 'default'}

# These defaults mirror the native block. A regression test checks equality so
# reset cannot quietly diverge from a freshly downloaded script.
FACTORY_SETTINGS = {
    'DEFAULT_COMPILER': 'GCC', 'DEFAULT_STANDARD': 'auto',
    'DEFAULT_SOURCE': 'main.cpp', 'DEFAULT_TIMEOUT': 'inf',
    'DEFAULT_MEMORY_LIMIT': 'inf', 'DEFAULT_INPUT': 'input.txt',
    'DEFAULT_OUTPUT': 'output.txt', 'DEFAULT_ANSWER': 'ans.txt',
    'DEFAULT_REPORT': 'test_out', 'DEFAULT_SEPARATOR': r'\n\n',
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
        'pragma': '-O3 -funroll-loops',
        'pragma-fast': '-funroll-loops -fno-stack-protector -ffast-math',
        'pragma-native': '-funroll-loops -fno-stack-protector -ffast-math',
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
    decoded = value.replace(r'\n', '\n')
    allowed = set('\n abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#=_.:+-')
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
              '-arch', '-B', '-Xlinker', '-Xclang', '-Xpreprocessor', '-mllvm'}
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
    if '/' in value or value in ('.', '..') or not value.endswith('.cpp'):
        raise ValueError('use a .cpp filename without directory components')
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
        print('  Common: ' + (editor.data['MODE_FLAGS'].get(name, '') or '(none)'))
        print('  CPU: ' + editor.data['MODE_CPU'].get(name, 'default'))
        print('  Compiler/library adaptations are retained; preview expands them.')
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
    compiler = editor.data['DEFAULT_COMPILER']
    warnings = editor.data['WARNINGS_GCC' if compiler == 'GCC' else 'WARNINGS_CLANG']
    standard = editor.data['DEFAULT_STANDARD']
    if standard.isdecimal():
        standard = 'c++' + standard
    print('Result: --compiler={} {} {}'.format(compiler,
        '[newest supported ISO C++]' if standard == 'auto' else '-std=' + standard,
        shlex.join(editor.data['DEFAULT_FLAGS'] + warnings)))
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
        ('DEFAULT_F_MODE', 'Bare -f action', _settings_choice('macro', 'auto')),
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
            print('\ncp-run 1.0 defaults — changes stay pending until save')
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
                print('  7. Measurements\n  export FILE / import FILE: portable preferences (data only)')
                choice = editor.ask('defaults> [1–7 / export FILE / import FILE / show / undo / reset / help / save / cancel]: ')
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
    _settings_choice('macro', 'auto')(data['DEFAULT_F_MODE'])
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
    names = data['MODE_NAMES']
    if len(set(names)) != len(names): raise ValueError('duplicate profile name')
    reserved = {'compile', 'run', 'test', 'stress', 'tr', 'sr', 'none', 'plain'}
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
    record = {'format': 'cp-run-settings', 'schema': 1, 'settings': data}
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
            or record['schema'] != 1):
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
            stream.write(os.fsencode(config['executable']) + b'\0')
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
    for key in ('auto', 'cin', 'cout', 'show_time', 'show_memory', 'show_command', 'warmup'):
        config[key] = config.get(key, '0') == '1'
    config['cases'] = [int(value) for value in config.get('cases', '').split(',') if value]
    for key in ('num_test', 'seed'):
        if config.get(key, '') == '':
            config.pop(key, None)
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
