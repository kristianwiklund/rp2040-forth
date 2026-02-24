# Bug 015: `OPEN-FILE` on missing path — device echoes definition back

## Summary

Test 14.2: defining and calling a word that uses `S"` and `OPEN-FILE` on a
non-existent path does not produce the expected output. The device echoes the
word body back instead of executing the compiled word.

## Test

```
14.2  OPEN-FILE on missing path: ior nonzero
```

Input sent:
```forth
: T14B S" /rom/nosuch" 0 1 OPEN-FILE SWAP DROP 0 > . ; T14B
```

Expected output:
```
1
```

## Observed Behaviour

```
<<T14B>> S" /rom/nosuch" 0 1 OPEN-FILE SWAP DROP 0 > . ; T14B ?
(c):
```

The device echoed the word body starting from the word name `T14B`, followed
by a `?` (unknown word) and a compile-mode prompt. The expected result `1 `
was not printed.
