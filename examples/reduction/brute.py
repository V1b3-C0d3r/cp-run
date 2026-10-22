"""Trusted reference for the declared counted-integer-sequence format."""
import sys
values = list(map(int, sys.stdin.read().split()))[1:]
print(sum(values))
