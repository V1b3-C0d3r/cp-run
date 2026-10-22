#!/bin/zsh -f
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 cp-run contributors
# One C, C++ or Python source, one selected output, and an optional run. Requires zsh 5.9.

# Start from native, predictable options instead of inheriting interactive
# customizations. Expected failures are checked explicitly, without ERR_EXIT.
emulate -LR zsh
setopt NO_UNSET PIPE_FAIL EXTENDED_GLOB
unsetopt ALIASES
typeset -r PROGRAM=cp-run VERSION=1.1.1
typeset -r SCRIPT_PATH=${0:A} # Settings follow the real script when invoked through a symlink.

# @NATIVE_SETTINGS@


fail() { printf '%s: %s\n' "$PROGRAM" "$1" >&2; exit "${2:-2}"; }

compiler_operand() {
    case "$1" in
        -I|-isystem|-iquote|-idirafter|-include|-imacros|-isysroot|--sysroot|-target|--target|-arch|-resource-dir|-gcc-toolchain|--gcc-toolchain|--gcc-install-dir|-B|-D|-U|-stdlib++-isystem|-o|--output|-l|-L|-Xlinker|-MF|-MT|-MQ|-MJ|--std) return 0 ;;
        *) return 1 ;;
    esac
}

