# Bug 003: `TYPE` has wrong stack signature and unsafe implementation

## Summary

`TYPE` is implemented as a raw `bl printf` on a single stack address. Standard
Forth `TYPE` takes `( addr u -- )` — an address and a character count. This
implementation takes only `( addr -- )` and passes the address directly to
`printf` as a format string, which is both wrong (ignores length) and unsafe
(any `%` in the string crashes or produces garbage).

## Location

`src/output.h`, lines 38–43:

```asm
# print a string from ascii pointed to by an item on the stack
HEADER "TYPE",4,0,TYPE
KPOP
bl printf      // r0 = addr used directly as printf format string
DONE
```

## Problems

### 1. Wrong stack effect

Standard Forth: `TYPE ( addr u -- )` — prints exactly `u` characters from `addr`.
This implementation: `( addr -- )` — ignores any length argument; prints until a
null byte is found. Any code that pushes `( addr u )` onto the stack before calling
`TYPE` will leave a stale `u` on the stack.

The `."` word in compile mode (from `forthdefs.h`) uses:
```forth
S" LIT TYPE ,
```
`S"` compiles a null-terminated string. `TYPE` receives only the address (the `LIT`
pushes it). The length is never pushed, so this accidentally works — but only
because the string is null-terminated and contains no `%`.

### 2. `printf` format-string injection

`printf(addr)` treats `addr` as a format string. A string containing `%` (e.g.
`." 50% done "`) will misinterpret the format specifiers, print garbage, and may
read arbitrary stack memory or fault.

### 3. Null termination assumed

`printf` stops at a null byte, not at the Forth length field. Strings that are not
null-terminated (or share a buffer with non-null bytes after them) will overprint.

## Fix

Option A — minimal: change `bl printf` to `bl puts` or write a counted-byte loop
using `putchar`. Still deviates from the standard `( addr u -- )` signature.

Option B — correct: pop both `u` and `addr`, then emit `u` characters via `putchar`
in a loop:

```asm
HEADER "TYPE",4,0,TYPE
KPOP            // r0 = u (count)
mov r2,r0
KPOP            // r0 = addr
mov r1,r0
// loop: emit r2 bytes from r1
_type_loop:
cmp r2,#0
beq _type_done
ldrb r0,[r1]
push {r1,r2}
bl putchar
pop {r1,r2}
add r1,#1
sub r2,#1
b _type_loop
_type_done:
DONE
```

This would require updating the `."` compile path in `forthdefs.h` to also push the
string length.

## Severity

Medium — `."` works for simple strings by accident. Any string with `%` will crash
or corrupt output. The wrong stack effect is a silent incompatibility with standard
Forth code.
