#pragma once

// Clang does not implement these GCC pragmas. cp-run's optimization profiles
// use driver options instead, so both compilers receive working optimizations.
#if defined(__GNUC__) && !defined(__clang__)
#  if defined(CP_RUN_FAST_PRAGMAS)
#    pragma GCC optimize("Ofast,unroll-loops,no-stack-protector,fast-math")
#  else
#    pragma GCC optimize("O3,unroll-loops")
#  endif
#endif

// CPU instruction sets are deliberately not hard-coded. cp-run's pragma-native
// profile asks the actual compiler about its current target and native support.
