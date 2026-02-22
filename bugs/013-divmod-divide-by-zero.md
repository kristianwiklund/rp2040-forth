# Bug 013: `/MOD` with divisor zero pushes garbage and continues silently

## Summary

`10 0 /MOD` does not hang (the RP2040 SIO hardware divider always
completes in 8 cycles regardless of the divisor) but the quotient and
remainder registers contain hardware-undefined values. The original code
wrote 0 directly to `SIO_DIV_SDIVISOR` and read back garbage, pushing two
undefined words onto the stack and returning normally. Any subsequent
computation was silently wrong.

## Location

`src/mathwords.h`, the RP2040 `/MOD` implementation.

## Observed Behaviour

```forth
10 0 /MOD . .    \ printed two garbage values, no error
```

The firmware did not hang or fault; it continued with a corrupted stack.

## Root Cause

No zero-check before the SIO write:

```asm
KPOP
str r0, [r3, #SIO_DIV_SDIVISOR_OFFSET]   // 0 written to hardware
KPOP
str r0, [r3, #SIO_DIV_SDIVIDEND_OFFSET]
// 8-cycle delay
ldr r0, [r3, #SIO_DIV_REMAINDER_OFFSET]  // undefined garbage
KPUSH
ldr r0, [r3, #SIO_DIV_QUOTIENT_OFFSET]   // undefined garbage
KPUSH
```

The RP2040 datasheet (section 2.3.1.5) states the result registers are
"undefined" while `SIO_DIV_CSR` READY is low, and that behaviour on
divisor=0 is implementation-defined. There is no hardware exception or
fault — only garbage output.

## Fix

Add `cmp r0,#0 / beq _divmod_zero` after the first `KPOP` (divisor),
before any SIO register write. The `_divmod_zero` handler pops the
dividend to restore a clean stack, prints `"division by zero\n"` via
`printf`, and returns via `DONE`.

```asm
KPOP                                    // r0 = divisor
cmp r0,#0
beq _divmod_zero
str r0, [r3, #SIO_DIV_SDIVISOR_OFFSET]
...

_divmod_zero:
    KPOP                                // discard dividend
    ldr r0,=divbyzero_msg
    bl printf
    DONE
```

Stack effect on divide-by-zero: `( n1 n2 -- )` — both operands consumed,
nothing pushed, error printed.

## Severity

Medium — no crash or hang, but silent stack corruption on any divide-by-zero
input (e.g. modular arithmetic with a user-supplied denominator).
