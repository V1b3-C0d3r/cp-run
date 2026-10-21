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

