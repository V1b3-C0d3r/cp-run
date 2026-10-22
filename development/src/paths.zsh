# Resolve workspace routing once, for compilation or run --find.
# An explicit binary path skips this branch just like an explicit -o path.
resolve_workspace_root() {
    [[ -z $workspace ]] || return 0
    local requested
    if (( name_given )); then
        case "$workspace_name" in ''|.|..|*/*) fail 'workspace name must be one nonempty directory name' ;; esac
    fi
    if (( dir_given || ! name_given )); then
        requested=$workspace_dir
        case "$requested" in
            .|./|"$cwd"|"$cwd"/) workspace=${cwd:A} ;;
            *)
                if [[ $requested != /* ]]; then requested="$cwd/$requested"; fi
                workspace=$(cd -q -P -- "$requested" 2>/dev/null && pwd -P) ||
                    fail "workspace directory is not accessible: $requested" 1 ;;
        esac
        if (( name_given )) && [[ ${workspace:t} != "$workspace_name" ]]; then
            fail "workspace name '$workspace_name' does not match directory '${workspace:t}'"
        fi
    else
        workspace=${cwd:A}
        while [[ ${workspace:t} != "$workspace_name" ]]; do
            [[ $workspace != / ]] || fail "workspace folder not found: $workspace_name" 1
            workspace=${workspace:h}
        done
    fi
    workspace_prefix="${workspace%/}/" # Exactly one separator, also for '/'.
}

resolve_workspace() {
    resolve_workspace_root
    case "$destination" in
        '{wsp-dir}') destination=. ;;
        '{wsp-dir}/'*) destination=${destination#'{wsp-dir}/'} ;;
    esac
    [[ -n $destination && $destination != /* ]] || fail 'destination must be a nonempty relative path'
    case "/$destination/" in */../*) fail 'destination must not contain .. components' ;; esac
    output_dir="$workspace_prefix$destination"
}

# Expand only an explicit workspace prefix. Resolving the root separately
# keeps -o's destination bypass intact when an input uses a workspace anchor.
workspace_file_path() {
    value=$1
    [[ $value == *'{wsp-dir}'* ]] || return 0
    local relative candidate
    case "$value" in
        '{wsp-dir}/'*) relative=${value#'{wsp-dir}/'} ;;
        *) fail 'use {wsp-dir}/PATH at the beginning of a file path' ;;
    esac
    [[ -n $relative && $relative != /* && $relative != *'{wsp-dir}'* ]] || fail 'invalid workspace file path'
    case "/$relative/" in */../*) fail 'workspace file path must not contain .. components' ;; esac
    resolve_workspace_root
    candidate="${workspace%/}/$relative"
    case "${candidate:A}" in
        "$workspace"|"$workspace_prefix"*) value=$candidate ;;
        *) fail 'workspace file path escapes workspace through a symbolic link' ;;
    esac
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
    if [[ -n $fallback ]]; then
        workspace_file_path "$fallback"; fallback=$value
        if [[ -f $fallback ]]; then source_file=$fallback; return; fi
    fi
    (( ! ${#sources} )) || fail "cannot select $preferred source: provide FILE or create $fallback"
    # With no preferred-language source, accept a unique other-language source
    # or a unique conventional fallback. Never resolve ambiguity by glob order.
    sources=(./*.(cpp|cc|cxx|C|c|py)(N-.))
    if (( ${#sources} == 1 )); then source_file=${sources[1]#./}; return; fi
    for candidate in "$DEFAULT_SOURCE" "$C_SOURCE" "$PYTHON_SOURCE"; do
        workspace_file_path "$candidate"; candidate=$value
        [[ ! -f $candidate ]] || fallbacks+=("$candidate")
    done
    if (( ${#fallbacks} == 1 )); then source_file=${fallbacks[1]}; return; fi
    fail "cannot select a source: provide FILE (found ${#sources} supported files)"
}
