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
    local -a sources=(./*.cpp(N-.))
    if (( ! ${#sources} )) && [[ ! -f $DEFAULT_SOURCE ]]; then
        sources=(./*.(cc|cxx|C|c|py)(N-.))
        if (( ${#sources} != 1 )); then
            local -a fallback=() candidate
            for candidate in "$C_SOURCE" "$PYTHON_SOURCE"; do [[ ! -f $candidate ]] || fallback+=("$candidate"); done
            if (( ${#fallback} == 1 )); then source_file=${fallback[1]}; return; fi
        fi
    fi
    if (( ${#sources} == 1 )); then source_file=${sources[1]#./}
    elif [[ -f $DEFAULT_SOURCE ]]; then source_file=$DEFAULT_SOURCE
    else fail "cannot select a source: found ${#sources} .cpp files and no $DEFAULT_SOURCE"; fi
}

