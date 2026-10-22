"""A deterministic seeded sequence, always containing the triggering value."""
import random
import sys
rng = random.Random(int(sys.argv[1]))
values = [rng.randrange(7) for _ in range(6)]
values[rng.randrange(len(values))] = 7
print(len(values))
print(*values)
