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
    if (( save_relpath && ! destination_given )) && [[ -z ${MODE_DEST_DIR[$profile]-}${ACTION_DEST_DIR[$key]-}${ACTION_DEST_DIR[$base]-}${ACTION_DEST_DIR[$parent]-} ]]; then
        destination=$DEFAULT_RELPATH_DESTINATION
    fi
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
