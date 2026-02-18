# Architectural Improvement Proposals

Derived from a structured review of the codebase. Ordered by priority.

---

## [DONE] #1 — Make SWAP, ROT, OVER native assembler words

**Problem:** `SWAP` and `ROT` were defined in `forthdefs.h` using `HERE` as a scratch
register:
```forth
: SWAP >R HERE ! R> HERE @ ;
: ROT  >R >R HERE ! R> R> HERE @ ;
```
`HERE` points to the top of the dictionary. Using it as a temp clobbers the dictionary
pointer if anything advances `DP` between the store and load — which happens during
compilation. `OVER` was downstream of the broken `SWAP`/`ROT`.

**Fix:** Native assembler implementations in `src/forth.S` using `r4`/`r5`/`r6` as
temporaries. Broken Forth definitions removed from `src/forthdefs.h`.

---

## #2 — Stack underflow/overflow detection in `_kpop` and `CFPOP`

**Problem:** The value stack and frame stack have no bounds checking. A stack underflow
silently corrupts adjacent memory and is the most common class of Forth bug. Currently the
only symptom is a crash or silent wrong result, often far from the actual cause.

**Proposal:** Add a compile-time constant for each stack bottom address. In `_kpop`, after
advancing the stack pointer, compare it against the known bottom before dereferencing:

```asm
_kpop:
    push {r1, r2, lr}
    ldr r1, =vstackptr
    ldr r0, [r1]
    add r0, #INTLEN
    ldr r2, =stackbottom        @ lowest valid address
    cmp r0, r2
    bhi _kpop_underflow         @ above bottom means underflowed
    str r0, [r1]
    ldr r0, [r1]
    ldr r0, [r0]
    pop {r1, r2, pc}
_kpop_underflow:
    ldr r0, =underflow_msg
    bl printf
    @ reset stacks and restart interpreter
    bl resetme
    ldr r0, =done
    mov pc, r0
```

Same principle for `CFPOP` on the frame stack.

A guard word (known constant, e.g. `0xDEADC0DE`) placed at each stack bottom gives an
additional tripwire for overflow in the other direction.

---

## #3 — Dedicate registers for stack pointers

**Problem:** `vstackptr` and `forthframestackptr` are globals in `.data`. Every `KPUSH` /
`KPOP` costs a function call (`bl _kpush` / `bl _kpop`) plus two indirect memory accesses
to load the pointer and update it — roughly 17–19 cycles per push/pop.

**Proposal:** Assign permanent registers:

```
r6 = Forth data stack pointer (DSP)
r7 = Forth return/frame stack pointer (RSP)
```

Push/pop then become 2-instruction inline sequences:

```asm
@ KPUSH r0 (value stack)
sub r6, #4
str r0, [r6]

@ KPOP r0
ldr r0, [r6]
add r6, #4

@ CFPUSH r0 (frame stack)
str r0, [r7]
sub r7, #4

@ CFPOP r0
add r7, #4
ldr r0, [r7]
```

This eliminates `_kpush`, `_kpop`, and the `CFPUSH`/`CFPOP` macros' use of the ARM CPU
stack to save/restore r6/r7. It also removes the coupling between the CPU stack and the
Forth frame stack during macro execution.

**Scope:** Wide — every word using `KPOP`, `KPUSH`, `CFPUSH`, `CFPOP` must be updated, and
r6/r7 must be initialised to the stack base addresses at startup (`resetme`).

---

## #4 — Dedicate a register for the instruction pointer (IP)

**Problem:** `wordptr` is a global variable. The inner interpreter loop (`done`/`execute`
in `forth.S`) does a `ldr r0, =wordptr` (literal pool load) followed by `ldr r1, [r0]`
(indirect load) on every single word dispatch. Every word call and return also reads and
writes this global.

**Proposal:** Assign `r5` as the permanent Forth instruction pointer. The inner interpreter
becomes a tight register-only loop:

```asm
inner_loop:
    ldr r0, [r5]        @ fetch CFA at IP
    adds r5, #4         @ advance IP
    cmp r0, #0
    beq end_of_list
    ldr r1, [r0, #OFFSET_EXEC]
    cmp r1, #0
    beq is_variable
    ldr r2, [r1]
    ldr r3, =0xabadbeef
    cmp r2, r3
    beq is_forth_word
    bx r1               @ native word
is_forth_word:
    @ save current IP (r5) on frame stack, load new IP
    str r5, [r7]
    subs r7, #4
    adds r1, #INTLEN    @ step past sentinel
    mov r5, r1
    b inner_loop
end_of_list:
    @ pop return IP from frame stack
    adds r7, #4
    ldr r5, [r7]
    cmp r5, #0
    bne inner_loop
    b reallydone
```

**Scope:** Wide — depends on #3 (r6/r7 as stack registers). Also requires initialising r5
at startup and preserving it across any calls out to C (e.g. `printf`). Should be done
after #3.

---

## #5 — Replace the `0xabadbeef` sentinel with a flag bit

**Problem:** Distinguishing native words from Forth-defined words currently requires
dereferencing the exec pointer and comparing the first 4 bytes to `0xabadbeef`. This is an
extra memory load on every word dispatch, and is architecturally unsound (a native word
whose first bytes happen to equal the sentinel would be misidentified).

**Proposal:** Add a flag bit in the header flags field:

```c
#define FLAG_FORTH_WORD  0x10
```

Set it in `FHEADER` instead of emitting the sentinel. Detection in the inner interpreter
becomes a single bit test on the already-loaded flags word, with no extra memory access.

Changes required:
- Add `FLAG_FORTH_WORD` to `themacros.h`
- Update `FHEADER` macro to set the flag instead of emitting `.int 0xabadbeef`
- Update the inner interpreter dispatch to test the flag bit
- Update `SEE` which also checks for the sentinel
- Remove the `0xabadbeef` check in `compile.h` (`:` word compiles the sentinel today)

**Scope:** Moderate — touches `themacros.h`, `forth.S`, `compile.h`, and `SEE`.

---

## #6 — Add stack-effect comments to all assembler words

**Problem:** Most native words in `forth.S`, `compile.h`, `terminal.h`, `output.h`, and
`mathwords.h` lack `( before -- after )` stack-effect comments. This makes it hard to
verify correctness and understand the system.

**Proposal:** Add a standard Forth stack-effect comment above every `HEADER`/`FHEADER`
definition:

```asm
// ( a b -- b a )
HEADER "SWAP",4,0,SWAP
```

Use the `#:` prefix convention (already documented in `scripts/gendocs.sh`) so the
documentation generator picks them up:

```asm
#: SWAP ( a b -- b a ) ; swap top two stack items
HEADER "SWAP",4,0,SWAP
```

**Scope:** Additive only, no functional changes.
