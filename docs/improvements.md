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
to load the pointer and update it — roughly 17–19 cycles per push/pop. CFPUSH/CFPOP save
and restore r6/r7 via the ARM CPU stack on every invocation.

**Register assignment:**

```
r6 = Forth data stack pointer (DSP)   — initially stacktop
r7 = Forth return/frame stack pointer (RSP) — initially forthframestackend
```

r6 and r7 are callee-saved per AAPCS, so all C function calls (`bl printf`, `bl putchar`,
etc.) already preserve them automatically. No special handling required around C calls.

**Stack convention (unchanged from current):**
- Value stack: store-first, then decrement (r6 points to next-free below top item).
  `KPUSH`: `str r0,[r6]; sub r6,#4`
  `KPOP`: `add r6,#4; ldr r0,[r6]`
- Frame stack: identical convention with r7.
  `CFPUSH`: `str \reg,[r7]; sub r7,#4`
  `CFPOP`: `add r7,#4; ldr \reg,[r7]`

**Bounds checks** carry over from #2. With registers as pointers the checks become inline
in the macros using a push/pop of a scratch register around the comparison. ARMv6-M LDM/STM
(including POP/PUSH) does not modify APSR flags, so the pattern is safe:

```asm
// KPOP — value stack underflow check
push {r1}
ldr  r1,=stacktop
cmp  r6,r1               // r6 >= stacktop means stack is empty
pop  {r1}                // safe: POP does not change APSR on ARMv6-M
bhs  _kpop_uflow_\@
add  r6,#4
ldr  r0,[r6]
b    _kpop_done_\@
_kpop_uflow_\@:
ldr  r0,=underflow_msg
bl   printf
bl   _stack_restart      // bl for long-range; _stack_restart never returns
_kpop_done_\@:

// KPUSH — value stack overflow check
push {r1}
ldr  r1,=stackbottom
cmp  r6,r1               // r6 <= stackbottom means no room to push
pop  {r1}
bls  _kpush_oflow_\@
str  r0,[r6]
sub  r6,#4
b    _kpush_done_\@
_kpush_oflow_\@:
ldr  r0,=overflow_msg
bl   printf
bl   _stack_restart
_kpush_done_\@:
```

CFPOP/CFPUSH follow the same pattern comparing r7 against `forthframestackend` /
`forthframestackstart`.

---

### Implementation checklist

#### `src/themacros.h`
- [ ] Rewrite `KPOP` macro: inline add+ldr with underflow check (as above)
- [ ] Rewrite `KPUSH` macro: inline str+sub with overflow check (as above)
- [ ] Rewrite `CFPOP` macro: inline add+ldr with underflow check (r7 is RSP, no push/pop of r6/r7 needed)
- [ ] Rewrite `CFPUSH` macro: inline str+sub with overflow check
- [ ] Remove `KPOP` / `KPUSH` as `bl _kpop` / `bl _kpush` (now inline)

#### `src/forth.S`
- [ ] `resetme`: add `ldr r6,=stacktop` and `ldr r7,=forthframestackend` to initialise
      the register stack pointers (keep the existing `.data` variable assignments for
      reference during debugging)
- [ ] `_stack_restart`: replace the vstackptr/forthframestackptr memory writes with
      direct register assignments `ldr r6,=stacktop` / `ldr r7,=forthframestackend`
- [ ] Delete `_kpush` and `_kpop` function bodies
- [ ] `vstackptr` global: remove (no longer written; r6 is authoritative)
- [ ] `forthframestackptr` global: remove (r7 is authoritative)
- [ ] `SPFETCH` (SP@): change `ldr r0,=vstackptr; ldr r0,[r0]` → `mov r0,r6`
- [ ] `RPFETCH` (RP@): change `ldr r0,=forthframestackptr; ldr r0,[r0]` → `mov r0,r7`
- [ ] `RPSTORE` (RP!): change `ldr r1,=forthframestackptr; str r0,[r1]` → `mov r7,r0`
- [ ] `findhelper` (lines ~419-427): r6 used as a word-name pointer — change to r3
      (r3 is a caller-saved scratch register)
- [ ] `ROT` word: r6 used as a temp (`push {r4,r5,r6}`) — change to r3, update
      push/pop accordingly (or drop push/pop entirely since inline KPOP/KPUSH no
      longer make function calls that would clobber r4/r5)
- [ ] `STACKTRACE` (ST word, lines ~671-700): uses r7 as a loop pointer and r6 to
      load `forthframestackptr`. Rewrite to use r5 as the loop pointer and read RSP
      from r7 directly. r5 must be saved/restored around the loop body since this
      word calls `bl printf`.

#### `src/convert.S`
- [ ] `myitoa`: uses r7 as a local (string start pointer) but only saves r3–r5.
      Change `push {r3-r5,lr}` / `pop {r3-r5,pc}` to `push {r3-r7,lr}` /
      `pop {r3-r7,pc}` so r6 and r7 are properly saved and restored. This is also
      the correct AAPCS behaviour for callee-saved registers.
- [ ] `myatoi`: already uses `push {r3-r7,lr}` / `pop {r3-r7,pc}` — no change needed

#### `src/forth.S` — SWAP/OVER/ROT cleanup (optional, low risk)
The `push {r4,r5}` / `pop {r4,r5}` in SWAP and OVER were added because the old `bl
_kpush` / `bl _kpop` function calls could theoretically clobber r4/r5 (they do not, but
it was defensive). With inline KPOP/KPUSH there are no function calls and no risk.
The push/pop can be removed, but leaving them is harmless.

---

### Risk and sequencing notes

- **`myitoa` is the biggest landmine.** It currently clobbers r7 silently. Fix this
  first (add r7 to its push/pop lists) before enabling the register convention, or the
  `.` (DOT) word will corrupt RSP on every number print.
- **`findhelper` clobbers r6.** Fix before enabling, or FIND will corrupt DSP.
- **Test order:** flash, type `1 2 + .` (exercises KPUSH, KPOP, ADD, DOT/myitoa).
  Then `1 2 3 ROT .S` (exercises ROT and STACKTRACE indirectly). Then `: FOO 42 . ;
  FOO` (exercises CFPUSH/CFPOP via the call/return path).

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
