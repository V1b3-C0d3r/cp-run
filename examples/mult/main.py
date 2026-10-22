"""One independent sample per invocation, usable with CPython or PyPy."""
import sys
print(sum(map(int, sys.stdin.read().split())))
