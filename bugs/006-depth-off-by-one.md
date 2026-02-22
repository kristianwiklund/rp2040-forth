# Bug 006: `DEPTH` returns N+1 for a stack with N items

## Test

**2.8** — `1 2 3 DEPTH . DROP DROP DROP`
Got: `4`  Expected: `3`

## Summary

`DEPTH` is defined in `src/forthdefs.h` as:

```forth
: DEPTH SP0 SP@ - 4 / ;
```

`SP0` executes before `SP@`. Executing `SP0` pushes one value onto the stack, so
by the time `SP@` runs, the stack pointer reflects N+1 items, not N. The
subtraction therefore yields `(N+1)*4` and division gives `N+1`.

## Correct definition

Capture `SP@` before any depth-related push occurs by swapping the order:

```forth
: DEPTH SP@ SP0 SWAP - 4 / ;
```

With this order `SP@` pushes the pointer for N items (correct baseline), then
`SP0` adds one more item, `SWAP` reverses the subtraction direction, and the
result is still `N`.

## Severity

Medium — any word that relies on `DEPTH` for bounds (e.g. `DEPTH 0 > IF …`)
will be off by one. Also the direct cause of bug 007 (`.S` wrong output).
