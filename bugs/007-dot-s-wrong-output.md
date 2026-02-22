# Bug 007: `.S` prints garbage and wrong items

## Test

**2.9** — `10 20 30 .S DROP DROP DROP`
Got: `536872256 3 30 20 `  Expected: `10 20 30 `

## Summary

`.S` is defined in `src/forthdefs.h` as:

```forth
: .S DEPTH DUP 0 > IF BEGIN DUP 4 * SP0 SWAP - @ . 1- DUP 0< UNTIL THEN DROP ;
```

There are two compounding issues:

**Issue 1 – DEPTH is off by one (bug #006)**
With 3 items on the stack DEPTH returns 4, so the loop iterates 4 times. The
fourth (extra) iteration reads one slot below the valid stack and prints a
garbage value (`536872256`).

**Issue 2 – Loop counter range reads counter slot, misses deepest item**
The address formula `DUP 4 * SP0 SWAP -` computes `SP0 - counter*4`.  The
counter is `DEPTH` (=3 with correct DEPTH) and occupies a slot at `SP0-12`.
The loop runs `counter = N … 1`, reading:

| counter | address    | value          |
|---------|------------|----------------|
| 3       | SP0 − 12   | depth counter  | ← wrong
| 2       | SP0 − 8    | 30 (TOS)       | ← correct
| 1       | SP0 − 4    | 20             | ← correct
| (0)     | SP0 − 0    | 10 (bottom)    | ← never read

The deepest item (10) is never printed and the depth counter (3) is printed in
its place.

## Severity

Medium — `.S` is used for interactive stack inspection; its output is wrong
for every call with more than one item.
