# Bug 002: `RECURSE` causes a hard crash

## Summary

The word `RECURSE` causes a hard crash (likely a fault in the FIND loop) when
invoked. The `FAC` (factorial) test word, which uses `RECURSE`, is therefore also
broken. This regression appeared after the migration to PlatformIO.

## Location

`src/forthdefs.h`, lines 29–30 and 102–105:

```c
// line 30 — RECURSE definition
.ascii ": RECURSE LATEST @ UNHIDE ; IMMEDIATE "

// lines 102–105 — FAC uses RECURSE, crash documented here
// recurse causes a hard crash in the find loop after the change to platformio
// focusing on integer output words atm, commenting out this
.ascii ": FAC ( factorial x -- x! ) RECURSE DUP 0> IF DUP 1- FAC * ELSE DROP 1 THEN ; "
```

## Observed Behaviour

Running `FAC` (or any word compiled with `RECURSE`) causes a hard crash. The
interpreter does not recover; a power-cycle or reflash is required.

## Probable Cause

`RECURSE` is defined as:

```forth
: RECURSE LATEST @ UNHIDE ; IMMEDIATE
```

At compile time of a word, `RECURSE` is supposed to compile a self-call by
appending the current word's own header address. However the definition only calls
`UNHIDE` — it does not actually compile the self-reference (no `COMMA`). The likely
sequence of events:

1. At compile time of e.g. `FAC`, `RECURSE` runs immediately (it is `IMMEDIATE`).
2. It calls `LATEST @` (address of the word being compiled) and `UNHIDE` (clears
   HIDDEN flag prematurely), but pushes the address without calling `,` to compile
   it into the word body.
3. The stack is corrupted or the word body is malformed.
4. When `FAC` is later executed, the inner interpreter follows a garbage pointer,
   landing in the FIND loop or elsewhere, and faults.

A correct `RECURSE` should compile the self-pointer, e.g.:
```forth
: RECURSE LATEST @ , ; IMMEDIATE
```
(with `HIDDEN` management handled separately so that the word is findable during
its own compilation).

## Affected Words

- `RECURSE` itself
- `FAC` (the only word in `forthdefs.h` that uses `RECURSE`)

## Workaround

Do not invoke `FAC` or define words using `RECURSE`. For manual recursion, use a
forward-declaration approach or rewrite the algorithm iteratively.

## Severity

High — crashes the interpreter, requires power-cycle to recover. `FAC` should
either be removed from `forthdefs.h` or guarded so it is not compiled at boot.
