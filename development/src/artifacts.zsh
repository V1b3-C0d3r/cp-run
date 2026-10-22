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

