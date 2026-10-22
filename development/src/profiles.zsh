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

