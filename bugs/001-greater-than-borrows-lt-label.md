# Bug 001: `>` word jumps to `_lt` label belonging to `<`

## Summary

The `>` (GREATERTHAN) word in `src/mathwords.h` contains `bgt _lt` which branches
to the label `_lt` defined inside the `<` (LESSTHAN) word. This works by accident
today but is latent wrong code: the `_gt` label (the intended true-branch) is
unreachable dead code.

## Location

`src/mathwords.h`, lines 88–101

```asm
#: < (n1 n2 -- f) 	; f is true if n1 > n2   <-- doc string also wrong (says "<")
HEADER ">",1,0,GREATERTHAN
KPOP
mov r1,r0
KPOP
cmp r0,r1
bgt _lt          // <-- branches to _lt inside the < word (line 83)
ldr r0,=0
KPUSH
DONE
_gt:             // <-- unreachable; never jumped to
ldr r0,=1
KPUSH
DONE
```

`_lt` is defined at line 83, inside LESSTHAN:

```asm
_lt:
ldr r0,=1
KPUSH
DONE
```

## Why It Works By Accident

`_lt` happens to contain the correct "true" result (`ldr r0,=1 / KPUSH / DONE`),
which is also the correct result when `n1 > n2` is true. So `>` produces correct
output today. However:

- If `<` or `>` is ever re-ordered, or labels are renamed, `>` silently breaks.
- `_gt` at line 98 is dead code and will never execute.
- The `#:` doc comment on line 88 says `< (n1 n2 -- f)` — a copy-paste error;
  it should say `> (n1 n2 -- f)`.

## Fix

Use a local label or a new distinct label for `>`:

```asm
HEADER ">",1,0,GREATERTHAN
KPOP
mov r1,r0
KPOP
cmp r0,r1
bgt _gt          // use _gt, not _lt
ldr r0,=0
KPUSH
DONE
_gt:
ldr r0,=1
KPUSH
DONE
```

Also fix the `#:` doc string to say `>`.

## Severity

Low — currently produces correct output. Risk becomes real if code is reorganised.
