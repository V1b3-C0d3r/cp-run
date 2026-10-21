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

