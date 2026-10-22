# History is user data, never sourced shell text. Native zsh I/O keeps the
# unlimited execution path independent of Python and external hash programs.
history_location() {
    local scope=${workspace:-$cwd} state_root=${XDG_STATE_HOME:-$HOME/.local/state}/cp-run/history
    local character stored= digest= hi lo
    local -i hash=1469598103934665603 code
    [[ -z $history_directory ]] || return 0
    # Stable FNV-style key plus a checked scope record: a collision can cause
    # an unavailable history slot, never selection of another workspace's file.
    for character in "${(@s::)scope}"; do
        printf -v code '%d' "'$character"
        (( hash = (hash ^ code) * 1099511628211 ))
    done
    printf -v digest '%08x%08x' $(( (hash >> 32) & 0xffffffff )) $(( hash & 0xffffffff ))
    zmodload -F zsh/files b:zf_mkdir b:zf_mv b:zf_rm || return 1
    local directory="$state_root/$digest"
    if ! zf_mkdir -p -m 700 -- "$directory" 2>/dev/null || [[ -L $directory || ! -O $directory ]]; then
        history_warn; return 1
    fi
    if [[ -e $directory/scope ]]; then
        IFS= read -r -d $'\0' stored < "$directory/scope" || { history_warn; return 1; }
        [[ $stored == "$scope" ]] || { history_warn; return 1; }
    else
        # Exclusive creation resolves concurrent first use without replacing
        # an already claimed scope. NUL terminates paths containing newlines.
        (umask 077; setopt NO_CLOBBER; printf '%s\0' "$scope" > "$directory/scope") 2>/dev/null || {
            IFS= read -r -d $'\0' stored < "$directory/scope" || { history_warn; return 1; }
            [[ $stored == "$scope" ]] || { history_warn; return 1; }
        }
    fi
    history_directory=$directory
}

history_warn() {
    if (( ! history_warning )); then
        printf '%s: warning: history is unavailable; explicit file execution continues\n' "$PROGRAM" >&2
        history_warning=1
    fi
}

history_read() {
    local marker= field
    [[ -f $history_directory/$1 && ! -L $history_directory/$1 ]] || fail "no last $1 in this workspace" 1
    {
        IFS= read -r -d $'\0' value || fail 'invalid history record' 1
        if [[ $1 == binary ]] && IFS= read -r -d $'\0' marker; then
            [[ $marker == CP_RUN_ARGV_V1 ]] || fail 'unsupported launch history record' 1
            while IFS= read -r -d $'\0' field; do
                (( ${#recalled_launch} < 256 )) || fail 'launch history has too many arguments' 1
                recalled_launch+=("$field")
            done
        fi
    } < "$history_directory/$1"
    [[ -n $value && -f $value && -r $value ]] || fail "last $1 is missing or unreadable: $value" 1
    [[ $1 != binary || $value == *.py || -x $value ]] || fail "last binary is no longer executable: $value" 126
    if (( ${#recalled_launch} )); then
        [[ ${recalled_launch[-1]} == "$value" && -x ${recalled_launch[1]} ]] || fail 'recorded interpreter/source is no longer available' 1
    fi
}

history_write() {
    history_location || return 0
    local temporary="$history_directory/.$1.$$.${RANDOM}${RANDOM}" target="$history_directory/$1"
    (umask 077; setopt NO_CLOBBER; printf '%s\0' "${@:2}" > "$temporary" && zf_mv -f -- "$temporary" "$target") 2>/dev/null || {
        zf_rm -f -- "$temporary" 2>/dev/null; history_warn
    }
    return 0
}
