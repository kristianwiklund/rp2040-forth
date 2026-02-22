# Manual Test Suite

All tests are run interactively over USB CDC serial (`make serial`).
The interpreter echoes input, then prints output, then `ok` on the next readline
cycle. Output from `.` and `EMIT` arrives on the same line as the input echo,
before `ok`.

Words defined at boot (from `src/forthdefs.h`) are available: `A`, `B`, `DOUBLE`
are **not** pre-defined — define them in the session as shown.

**Known failing words — do not test:** `FAC`, `RECURSE` (hard crash, see
`bugs/002`). `TYPE` with strings containing `%` will also crash (see `bugs/003`).

---

## How to Run

```
make serial
```

Paste or type each input line and press Enter. The interpreter prints output
immediately, then `ok` when it is ready for the next line.

---

## 1. Basic Output

Verify the output path before anything else. If `.` does not work, nothing below is
meaningful.

| Input | Expected output | Notes |
|-------|----------------|-------|
| `42 .` | `42 ` | Basic number print |
| `0 .` | `0 ` | Zero |
| `-5 .` | `-5 ` | Negative literal |
| `32767 .` | `32767 ` | Multi-digit |
| `65 EMIT` | `A` | ASCII 65 = 'A'; uses `putchar` not `printf` |
| `65 EMIT CR 66 EMIT` | `A` (newline) `B` | CR = 10 EMIT |
| `65 EMIT SPACE 66 EMIT` | `A B` | SPACE = 32 EMIT |

---

## 2. Stack Manipulation

After each group, verify the stack is clean with `.S` (expect no output).

| Input | Expected output | Notes |
|-------|----------------|-------|
| `5 DUP . .` | `5 5 ` | DUP copies TOS |
| `1 2 DROP .` | `1 ` | DROP removes TOS |
| `1 2 SWAP . .` | `2 1 ` | SWAP: TOS=2 printed first |
| `3 4 OVER . . .` | `3 4 3 ` | OVER copies second item to top |
| `1 2 3 ROT . . .` | `1 3 2 ` | ROT: ( 1 2 3 -- 2 3 1 ), TOS=1 |
| `7 8 2DUP . . . .` | `8 7 8 7 ` | 2DUP = OVER OVER; stack becomes 7 8 7 8 |
| `99 NOP .` | `99 ` | NOP is a no-op |
| `1 2 3 DEPTH .` | `3 ` | Stack has 3 items; then `DROP DROP DROP` |
| `10 20 30 .S` | `10 20 30 ` | Prints all items without consuming them |

---

## 3. Arithmetic

| Input | Expected output | Notes |
|-------|----------------|-------|
| `3 4 + .` | `7 ` | |
| `0 0 + .` | `0 ` | |
| `3 -5 + .` | `-2 ` | Signed addition |
| `10 3 - .` | `7 ` | `-`: n2−n1, here 10−3 |
| `3 10 - .` | `-7 ` | Signed subtraction |
| `6 7 * .` | `42 ` | |
| `12345 0 * .` | `0 ` | Multiply by zero |
| `6 -7 * .` | `-42 ` | Signed multiply |
| `17 5 /MOD . .` | `3 2 ` | TOS=quotient(3), second=remainder(2) |
| `20 4 /MOD . .` | `5 0 ` | Exact division; zero remainder |
| `17 5 / .` | `3 ` | `/` = /MOD SWAP DROP |
| `17 5 MOD .` | `2 ` | `MOD` = /MOD DROP |
| `10 1- .` | `9 ` | `1-` = 1 - |

---

## 4. Comparison

Note: `>` uses `bgt _lt` (a label inside `<`) — see `bugs/001`. Results are
correct today but the implementation is fragile.

| Input | Expected output | Notes |
|-------|----------------|-------|
| `3 5 < .` | `1 ` | 3 < 5 → true |
| `5 3 < .` | `0 ` | 5 < 3 → false |
| `5 5 < .` | `0 ` | Equal is not less-than |
| `7 3 > .` | `1 ` | 7 > 3 → true |
| `2 8 > .` | `0 ` | 2 > 8 → false |
| `5 5 > .` | `0 ` | Equal is not greater-than |
| `4 4 = .` | `1 ` | Equal |
| `4 5 = .` | `0 ` | Not equal |
| `0 0= .` | `1 ` | Zero is zero |
| `42 0= .` | `0 ` | Non-zero is not zero |
| `0 NOT .` | `1 ` | NOT = 0= |
| `5 5 <= .` | `1 ` | Boundary: <= via `> NOT` |
| `5 5 >= .` | `1 ` | Boundary: >= via `< NOT` |
| `3 4 <> .` | `1 ` | Not equal |
| `7 7 <> .` | `0 ` | Equal → not-unequal |
| `-1 0< .` | `1 ` | Negative is < 0 |
| `1 0< .` | `0 ` | Positive is not < 0 |
| `5 0> .` | `1 ` | Positive is > 0 |
| `3 0<> .` | `1 ` | Non-zero is <> 0 |

---

## 5. Base / Number Representation

After switching to HEX, switch back to DEC before further tests.
Hex input must be **lowercase** — uppercase A–F are rejected (see `bugs/005`).

| Input | Expected output | Notes |
|-------|----------------|-------|
| `HEX ff . DEC` | `ff ` | Hex output is lowercase |
| `HEX 1a . DEC` | `26 ` | Hex input parsed as 26 decimal |
| `BASE @ .` | `10 ` | BASE holds the current radix |
| `HEX 0 . DEC` | `0 ` | Zero in hex |
| `HEX 1A . DEC` | *(error)* | Uppercase rejected — see `bugs/005` |

---

## 6. Control Flow

Define the test words first, then invoke them.

### IF / ELSE / THEN

```forth
: TESTIF IF 111 . ELSE 222 . THEN ;
```

| Input | Expected output | Notes |
|-------|----------------|-------|
| `1 TESTIF` | `111 ` | Non-zero → true branch |
| `0 TESTIF` | `222 ` | Zero → else branch |

```forth
: TESTIF2 IF 42 . THEN ;
```

| Input | Expected output | Notes |
|-------|----------------|-------|
| `1 TESTIF2` | `42 ` | True branch taken |
| `0 TESTIF2` | *(nothing)* | False branch; 0BRANCH skips to THEN |

### BEGIN / UNTIL

`A` is pre-defined at boot: `: A 10 BEGIN DUP . 1 - DUP 0 < UNTIL ;`

The loop prints 10 down to 0, then terminates when `0 1- → -1` satisfies `0<`.
The value `-1` remains on the stack when the word returns.

| Input | Expected output | Notes |
|-------|----------------|-------|
| `A .` | `10 9 8 7 6 5 4 3 2 1 0 -1 ` | -1 is left on stack after A, `.` prints it |

`B` is pre-defined at boot: `: B IF 1000 . ELSE 2000 . THEN ;`

| Input | Expected output | Notes |
|-------|----------------|-------|
| `1 B` | `1000 ` | |
| `0 B` | `2000 ` | |

---

## 7. Word Definition and Compilation

| Input sequence | Expected output | Notes |
|---------------|----------------|-------|
| `: DOUBLE 2 * ;` then `6 DOUBLE .` | `12 ` | Basic definition |
| `: SUMTHREE + + ;` then `1 2 3 SUMTHREE .` | `6 ` | Multiple ops |
| `: QUAD DOUBLE DOUBLE ;` then `3 QUAD .` | `12 ` | Nested Forth calls |
| `: ADD5 5 + ;` then `10 ADD5 .` | `15 ` | LIT compiled into word |
| `STATE .` | `0 ` | STATE=0 in interpret mode |
| `: MYIMM 999 . ; IMMEDIATE` then `: USEIMM MYIMM ;` | `999 ` | MYIMM runs at compile time of USEIMM |

---

## 8. Memory

| Input sequence | Expected output | Notes |
|---------------|----------------|-------|
| `CREATE MYVAR` then `42 MYVAR !` then `MYVAR @ .` | `42 ` | Variable create/store/fetch |
| `HERE .` | *(non-zero address)* | Current heap pointer |
| `65 CREATE MYBYTE C!` then `MYBYTE C@ .` | `65 ` | Byte store/fetch |

---

## 9. Return Stack

`>R` and `R>` are `FLAG_ONLYCOMPILE` but are not blocked in interpret mode. They
must be used inside a compiled word to be meaningful (using them interactively
corrupts the IP save on the return stack).

```forth
: TESTRS 10 >R 20 . R> . ;
```

| Input | Expected output | Notes |
|-------|----------------|-------|
| `TESTRS` | `20 10 ` | >R hides 10; . prints 20; R> retrieves 10 |

---

## 10. Dictionary and Decompiler

| Input | Expected output | Notes |
|-------|----------------|-------|
| `WORDS` | *(long word list)* | Hidden/invisible words excluded |
| `SEE +` | `<asm>` | Native word |
| `SEE /` | `<forth>` ... `/MOD SWAP DROP` | Forth-defined word |
| `SEE DP` | `<<variable>>` | exec ptr == 0 |

---

## 11. Error Recovery

| Input | Expected output | Notes |
|-------|----------------|-------|
| `DROP` *(on empty stack)* | `stack underflow` + prompt | KPOP bound check; restarts interpreter |
| `5 .` *(after underflow)* | `5 ` | Verifies _stack_restart reset r6 correctly |
| `R>` *(on empty return stack)* | `return stack underflow` + prompt | CFPOP bound check |

---

## 12. Edge Cases

| Input | Expected output | Notes |
|-------|----------------|-------|
| `2147483647 .` | `2147483647 ` | Near INT_MAX |
| `2147483647 1 + .` | `-2147483648 ` | Signed wrap-around (silent, ARM behaviour) |
| `0 5 /MOD . .` | `0 0 ` | Zero dividend |
| `10 0 /MOD` | *(undefined)* | RP2040 SIO hardware divider with divisor=0; document actual result; be ready to power-cycle |
| `-7 3 /MOD . .` | `-2 -1 ` | Signed division: truncation toward zero (TOS=quotient) |

---

## Recommended Execution Order

Run these in order — each group depends on the previous being healthy.

```forth
\ 1. Output
42 .
0 . -5 . 32767 .
65 EMIT

\ 2. Stack
5 DUP . .
1 2 SWAP . .
3 4 OVER . . .
1 2 3 ROT . . .

\ 3. Arithmetic
3 4 + .
10 3 - .
6 7 * .
17 5 /MOD . .
17 5 / .

\ 4. Comparisons
3 5 < .
7 3 > .
4 4 = .

\ 5. Error recovery
DROP
5 .

\ 6. Word definition
: DOUBLE 2 * ;
6 DOUBLE .

\ 7. Control flow (using pre-defined boot words)
1 B
0 B
A .

\ 8. Base
HEX ff . DEC

\ 9. Memory
CREATE MYVAR  42 MYVAR !  MYVAR @ .

\ 10. Return stack
: TESTRS 10 >R 20 . R> . ;
TESTRS

\ 11. Dictionary
WORDS
SEE /
```
