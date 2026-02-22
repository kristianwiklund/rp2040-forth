# Bug 004: `wordbuf2` shared between `WORD` output and `.` (DOT) scratch buffer

## Summary

`wordbuf2` is used as both the output buffer for the `WORD` word (address left on
the stack) and as the scratch buffer for `myitoa` inside `.` (DOT). Calling `.`
after `WORD` — while the address of `wordbuf2` is still live on the stack or being
relied upon — overwrites the word name with the number string.

## Location

- `src/terminal.h`, lines 207–231 — `WORD` copies the parsed word into `wordbuf2`
  and pushes its address.
- `src/output.h`, lines 11–12 — `DOT` calls `myitoa` with `wordbuf2` as the
  output buffer.

```asm
// terminal.h — WORD
ldr r1,=wordbuf2
...                  // copies parsed word name into wordbuf2
mov r0,r1            // r0 = wordbuf2 address
KPUSH                // pushed as ( wordbuf2_addr length )

// output.h — DOT
ldr r2,=wordbuf2
bl myitoa            // overwrites wordbuf2 with number string
ldr r0,=wordbuf2
bl printf
```

## Background

The original `WORD` pushed the address of `wordbuf` (the raw parse buffer). That
buffer was immediately overwritten by any subsequent word call that invoked
`newwordhelper`. The copy to `wordbuf2` was added as a fix for that first-layer
bug. However `wordbuf2` was already in use by `DOT` and nothing prevents a second
collision.

The code comment in `terminal.h` documents the first bug but not this remaining one:

```
// the bug is because
// subsequent use of other words will overwrite this buffer
// hence, we need to copy it to another buffer - wordbuf2
```

## Triggering Scenario

Any sequence where the address of `wordbuf2` is on the stack (or used as a string
pointer) and `.` is called before that address is consumed:

```forth
WORD + FIND .    \ FIND searches for "+"; . then overwrites wordbuf2; safe here
                 \ because FIND consumed the address before . ran

WORD . .         \ First . overwrites wordbuf2 with the numeric output of the top
                 \ stack item; second . prints that number but wordbuf2 no longer
                 \ holds the word name (not a real scenario but illustrates the alias)
```

A realistic problematic case arises if `WORD`'s result address is stored somewhere
and later used as a string, after an intervening `.` has clobbered `wordbuf2`.

## Fix

Give `DOT` its own scratch buffer (e.g. `numbuf`), separate from `wordbuf2`. Or
give `WORD` its own dedicated output buffer distinct from the one used by numeric
output words.

```asm
// output.h — DOT, use a dedicated buffer
ldr r2,=numbuf      // separate buffer, not wordbuf2
bl myitoa
ldr r0,=numbuf
bl printf
```

## Severity

Low — does not trigger in normal interactive use because `WORD`'s address is
consumed (by `FIND`, `COMMA`, `CMOVE`, etc.) before `.` is called. Becomes a real
bug in code that holds a `WORD` address across a `.` call.
