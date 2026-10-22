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
    if (( doctor_requested )); then
        config=(interpreter "$interpreter_choice" native_formatter "$NATIVE_FORMATTER" python_formatter "$PYTHON_FORMATTER")
        python_action doctor; return $?
    fi
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
        [[ $action == test || $action == stress || $f_mode == auto || $f_mode == out ]] || fail '--out requires test/stress or -f=auto/out'
    fi
    case "$f_mode" in none|auto|in|out) ;; macro) macro_file_io=1 ;; *) fail 'invalid saved -f mode; use --set-defaults' ;; esac
    [[ $DEFAULT_MACRO == [A-Za-z_][A-Za-z0-9_]# ]] || fail 'FILEO macro setting must be a C identifier'
    for option_name value in --TLE "$timeout_ms" --MLE "$memory_mib"; do
        [[ $value == inf ]] && continue
        [[ $value == <-> && ${#value} -le 12 ]] && (( 10#$value > 0 )) || fail "$option_name requires a positive integer (up to 12 digits) or inf"
    done
    cwd=$(pwd -P) || fail 'cannot resolve the current directory' 1
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
        workspace_file_path "$data_input"; data_input=$value
        workspace_file_path "$data_output"; data_output=$value
        # These defaults also supply the manual-file and .bundle names.
        if [[ $bundle_stream == in ]]; then workspace_file_path "$input_file"; input_file=$value
        else workspace_file_path "$answer_file"; answer_file=$value; fi
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
    if (( mult )) || [[ $action == companion || $action == pack || $action == unpack ]]; then
        resolve_workspace
    fi
    if [[ $action == companion ]]; then
        source_file=${source_file:-$DEFAULT_SOURCE}
        workspace_file_path "$source_file"; source_file=$value
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
        workspace_file_path "$source_file"; source_file=$value
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
            actual "$result_file" sep "$separator" cases "${(j:,:)cases}" num_test "$num_test"
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
