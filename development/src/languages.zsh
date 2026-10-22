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

python_launch() {
    local selected=$1 selected_profile=$2 word
    local -a extra=()
    resolve_interpreter
    launch_args=("$interpreter" "${PYTHON_FLAGS[@]}")
    # Primary backend tails apply only to roles of the same backend class.
    if [[ $primary_language == python ]]; then extra=("${compiler_args[@]}"); fi
    if [[ $selected_profile != none ]]; then
        local implementation
        implementation=$("$interpreter" -c 'import platform; print(platform.python_implementation())') || return $?
        local text=
        case "$implementation" in
            CPython) text=${MODE_CPYTHON[$selected_profile]-} ;;
            PyPy) text=${MODE_PYPY[$selected_profile]-} ;;
        esac
        [[ -n $text ]] || fail "profile '$selected_profile' has no $implementation configuration"
        launch_args+=("${(@Q)${(z)text}}")
        if [[ ${MODE_KIND[$selected_profile]} == debug ]]; then
            (( ! no_warnings )) || fail 'debug profile conflicts with --no-w'
            [[ ${PYTHONOPTIMIZE:-0} == 0 ]] || fail 'debug profile conflicts with PYTHONOPTIMIZE'
            for word in "${PYTHON_FLAGS[@]}" "${extra[@]}"; do
                case "$word" in -O|-OO|-Wignore|-Wignore:*|-Wdefault|-Wdefault:*) fail "debug profile conflicts with $word" ;; esac
            done
        fi
    fi
    if [[ $selected_profile != none && ${MODE_KIND[$selected_profile]} == debug ]]; then
        local -a audited=("${PYTHON_FLAGS[@]}" "${extra[@]}")
        local index filter
        for (( index=1; index<=${#audited}; ++index )); do
            word=${audited[index]}
            if [[ $word == -W ]]; then (( ++index )); filter=${audited[index]-}
            elif [[ $word == -W?* ]]; then filter=${word#-W}
            else continue; fi
            if [[ $filter == ignore* || $selected_profile == extra && $filter != error* ]]; then
                fail "debug profile conflicts with Python warning filter: $filter"
            fi
        done
    fi
    for word in "${launch_args[@]:1}" "${extra[@]}"; do
        case "$word" in -c|-m|--|--help|--version|-V|-i) fail "interpreter option replaces source execution: $word" ;; esac
    done
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
    local key=$action
    if [[ $action == test ]]; then
        (( ! auto )) || key=test-auto
        (( ! mult )) || key=test-mult
    fi
    if (( ! destination_given )); then
        destination=${MODE_DEST_DIR[$profile]-${ACTION_DEST_DIR[$key]-${ACTION_DEST_DIR[$action]-$DEFAULT_DESTINATION}}}
    fi
    if (( ! relpath_given )); then save_relpath=${MODE_SAVE_RELPATH[$profile]-${ACTION_SAVE_RELPATH[$key]-${ACTION_SAVE_RELPATH[$action]-0}}}; fi
    if (( ! test_relpath_given )); then save_test_relpath=${MODE_SAVE_TEST_RELPATH[$profile]-${ACTION_SAVE_TEST_RELPATH[$key]-${ACTION_SAVE_TEST_RELPATH[$action]-0}}}; fi
    if (( save_relpath && ! destination_given )) && [[ -z ${MODE_DEST_DIR[$profile]-}${ACTION_DEST_DIR[$key]-}${ACTION_DEST_DIR[$action]-} ]]; then
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
