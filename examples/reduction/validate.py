"""Require a nonempty sequence of at most 100 values in the range 0..10."""
import sys
try:
    data = list(map(int, sys.stdin.read().split()))
    valid = bool(data) and 1 <= data[0] <= 100 and len(data) == data[0] + 1
    valid = valid and all(0 <= value <= 10 for value in data[1:])
except ValueError:
    valid = False
raise SystemExit(0 if valid else 1)
