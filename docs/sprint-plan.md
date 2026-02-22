# Sprint Plan: Bug Fix Backlog

Produced from analysis of bugs/001–012 by the Forth expert and embedded software architect.

---

## Critical Finding

**Bug 002 is a boot-time timebomb.** Despite a comment in `forthdefs.h` indicating FAC is
being "commented out", line 105 is still a live `.ascii` line. FAC compiles RECURSE at
every power-on. Any test run that calls FAC hard-crashes the board and requires a reflash.

---

## Sprint 1 — Crash Prevention & Memory Integrity

*Goal: stop crashes and silent memory corruption before any further test runs.*

| # | Bug | Fix | Complexity |
|---|-----|-----|------------|
| 1 | **008** — `pushwordaddress` uses `OFFSET_EXEC` instead of `OFFSET_NAME` | `compile.h:54`: change `#OFFSET_EXEC` → `#OFFSET_NAME` | One-liner |
| 2 | **002** — RECURSE crashes; FAC compiles at boot | Step 1: comment out FAC in `forthdefs.h` (immediate mitigation). Step 2: fix RECURSE to use `LATEST @ ,` instead of `LATEST @ UNHIDE` | 1-liner mitigate / medium correct fix |
| 3 | **003** — `TYPE` wrong signature + `printf` format-string injection | Fix must be atomic with `."` compile path. Sub-task A: change `printf(addr)` to safe emit. Sub-task B: correct stack signature to `(addr u --)` and update `."` / `S"` accordingly. | Small–medium |

### Bug 003 Note

Correcting TYPE's stack signature to `(addr u --)` requires simultaneously updating the
`."` compile path in `forthdefs.h` and changing how `S"` pushes its result. Both sub-fixes
must land in the same commit or `."` breaks. Safe incremental path: first fix the `printf`
injection only, then tackle the full `(addr u --)` signature change as a second pass.

---

## Sprint 2 — Correctness & Developer Tooling

### 2a — Test Suite Corrections (no firmware changes)

Fix the test suite first so it can be used as a trustworthy regression harness for the
firmware fixes that follow.

| # | Bug | Fix | Complexity |
|---|-----|-----|------------|
| 4 | **010** — SWAP test expectation wrong | Change expected `"2 1"` → `"1 2 "` in `test/cases/stack.py` | One-liner |
| 5 | **011** — HEX output test wrong | Change test input to `HEX 1a DEC .` and keep expected `"26 "` (properly tests base-switching semantics) | One-liner |
| 6 | **012** — SEE format mismatch | Change test to regex match `r"/MOD.*SWAP.*DROP"`. Do **not** change SEE's address-per-line format — it is useful diagnostic information. | Small |

### 2b — Firmware Correctness

| # | Bug | Fix | Complexity | Dependency |
|---|-----|-----|------------|------------|
| 7 | **006** — `DEPTH` returns N+1 | `forthdefs.h`: change `: DEPTH SP0 SP@ - 4 / ;` → `: DEPTH SP@ SP0 SWAP - 4 / ;` | One-liner | Blocks 007 |
| 8 | **007** — `.S` prints garbage | Fix address formula after 006 is verified — also has independent off-by-one (reads counter slot, misses deepest item) | Small | Requires 006 |

#### Bug 007 root cause (recorded after fix)

KPUSH stores at `[r6]` **then** decrements r6. So with N items on the stack:
- `r6 = stacktop - N×4`  (DSP sits one word **below** TOS)
- TOS lives at `r6+4 = stacktop - (N-1)×4`
- Bottom item lives at `stacktop` (= `SP0`)

`.S` calls `DEPTH` first, which pushes the count (N) onto the stack, writing it at
`[stacktop - N×4]`. The loop body then computes `SP0 - k×4` for k = N…1. At k=N
that evaluates to `stacktop - N×4` — the slot just written by DEPTH's own KPUSH, not
the original TOS. And at k=1 it evaluates to `stacktop-4`, missing the bottom item
at `stacktop` entirely.

Fix: replace `SP0` with `SP0 4 +` in the loop. Now `(SP0+4) - k×4`:
- k=N:   `stacktop+4 - N×4`     = `stacktop - (N-1)×4`  = TOS   ✓
- k=N-1: `stacktop+4 - (N-1)×4` = `stacktop - (N-2)×4`  = NOS   ✓
- k=1:   `stacktop+4 - 1×4`     = `stacktop`             = bottom ✓
| 9 | **001** — `>` borrows `_lt` label from `<` | `mathwords.h`: change `bgt _lt` → `bgt _gt`; fix doc comment | One-liner | None |
| 10 | **004** — `wordbuf2` aliased between WORD and DOT | Give DOT its own `numbuf` scratch buffer in `output.h` | Small | None |

---

## Sprint 3 — Edge Case Polish

*No stability impact; workarounds exist for both.*

| # | Bug | Fix | Complexity |
|---|-----|-----|------------|
| 11 | **005** — `myatoi` rejects uppercase hex | `convert.S`: fold `A–Z` to `a–z` before range check (`or r3,#0x20`) | One-liner |
| 12 | **009** — `.` cannot print `INT_MIN` | `convert.S` / `myitoa`: add special-case guard before negate step | Small |

---

## Sprint 4 — Divide-by-Zero Safety

*Single firmware fix; no other open bugs in the original backlog.*

| # | Bug | Fix | Complexity |
|---|-----|-----|------------|
| 13 | **013** — `/MOD` pushes garbage on divisor=0 | `mathwords.h`: zero-check divisor before SIO write; `_divmod_zero` handler pops dividend, prints error | Small |

Test 12.4 promoted from permanent `skip` to `"match": "contains"`.

---

## Dependency Graph

```
008 ──────────────────────────────────────── (CREATE/VARIABLE now work)
002 (mitigate) ──→ 002 (correct fix) ──────── (FAC/RECURSE safe)
003 (printf fix) ──→ 003 (signature fix) ───── (TYPE/." safe)
                                ↕
          010, 011, 012 (test suite now trustworthy)
                                ↕
006 (DEPTH correct) ──→ 007 (.S correct) ──── (.S now usable for debugging)
001 ─────── (independent)
004 ─────── (independent)
005 ─────── (independent)
009 ─────── (independent)
```

---

## Summary

| Sprint | Bugs | Primary Goal |
|--------|------|--------------|
| **1**  | 008, 002, 003 | Stop crashes and memory corruption |
| **2a** | 010, 011, 012 | Make test suite trustworthy |
| **2b** | 006, 007, 001, 004 | Correct behavior + working debug tools |
| **3**  | 005, 009 | Edge case polish |
| **4**  | 013 | Divide-by-zero safety |
