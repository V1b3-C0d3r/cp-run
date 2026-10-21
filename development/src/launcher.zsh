# Payload arrives on fd 3; fd 0 remains the program/menu input. The bootstrap
# is constant-sized even when the embedded services grow beyond Linux argv limits.
embedded_python() {
    if [[ -z $python ]]; then python=$(whence -p -- python3 2>/dev/null) || fail 'this feature requires Python 3.9+' 127; fi
    # Services use only stdlib; -S avoids unnecessary site-package startup.
    # This affects the observer/editor, never the user's executable environment.
    "$python" -S -c 'import os; f=os.fdopen(3, "r", encoding="utf-8"); code=f.read(); f.close(); exec(compile(code, "<cp-run>", "exec"))' "$@" 3<<'CP_RUN_PYTHON'
# @EMBEDDED_PYTHON@
CP_RUN_PYTHON
}

main "$@"
