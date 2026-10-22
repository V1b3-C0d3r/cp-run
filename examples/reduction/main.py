"""Deliberate bug: the answer is one too large whenever the sequence has 7."""
import sys
values = list(map(int, sys.stdin.read().split()))[1:]
print(sum(values) + (1 if 7 in values else 0))
