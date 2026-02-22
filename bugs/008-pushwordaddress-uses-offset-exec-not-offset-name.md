# Bug 008: `pushwordaddress` uses `OFFSET_EXEC` (12) instead of `OFFSET_NAME` (16) — variable data area is 4 bytes too low

## Tests

**8.1** — `MYVAR @ .`  (setup: `CREATE MYVAR`, `42 MYVAR !`)
Got: `<<MYVAR>> @ . ?`  Expected: `42`

**8.3** — `MYBYTE C@ .`  (setup: `CREATE MYBYTE`, `65 MYBYTE C!`)
Got: `<<MYBYTE>> C@ . ?`  Expected: `65`

Additionally, `WORDS` shows the created words as `MYVA*` and `MYBYAE` — their
names are corrupted.

## Summary

When a `CREATE`d word with `exec ptr == 0` is executed, the interpreter falls
through to `pushwordaddress` (`src/compile.h`, line 49) which calculates the
address of the data area following the word's header:

```asm
pushwordaddress:
    ldr r2,[r0,#OFFSET_LENGTH]  // r2 = name length
    mov r1,r0                   // r1 = word start
    add r1,r2                   // r1 += name length
    add r1,#1                   // r1 += 1 (null terminator)
    add r1,#OFFSET_EXEC         // BUG: adds 12 instead of 16
    bl  alignhelper
    mov r0,r1
    KPUSH
    DONE
```

`OFFSET_EXEC` is 12; `OFFSET_NAME` is 16.  The data area is therefore 4 bytes
before where it should be, landing **inside the name field**.

For `MYVAR` (5-char name):

| Offset | Field            |
|--------|------------------|
| 0      | link             |
| 4      | flags            |
| 8      | length           |
| 12     | exec ptr         |
| 16     | 'M'              |
| 17     | 'Y'              |
| 18     | 'V'              |
| 19     | 'A'              |
| 20     | **'R'** ← `42 MYVAR !` stores 0x0000002A here → `*` |
| 21     | '\0'             |

The value `42` (0x0000002A) stored at the wrong address overwrites byte 20
(`'R'` = 0x52) with 0x2A (`'*'`), corrupting the name to `MYVA*`.  FIND then
fails to match `MYVAR` against the corrupted name, producing the `?` error.

For `MYBYTE` (6-char name) `65 MYBYTE C!` writes `0x41` (`'A'`) at byte 20,
changing `'T'` (0x54) to `'A'`, yielding `MYBYAE`.

## Fix

Change `OFFSET_EXEC` to `OFFSET_NAME` in `pushwordaddress`:

```asm
    add r1,#OFFSET_NAME         // was: add r1,#OFFSET_EXEC
```

## Severity

High — `CREATE` variables are silently corrupted on first write; the variable
becomes unaddressable afterward.
