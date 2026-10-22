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

