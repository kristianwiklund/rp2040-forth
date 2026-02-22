# Bug 005: `myatoi` rejects uppercase hex digits (A–F)

## Summary

`myatoi` in `src/convert.S` only recognises lowercase hex digits `a`–`f`. Typing
uppercase hex literals (e.g. `HEX 1A`) triggers the error path and the number is
not parsed. This is a silent failure — the interpreter treats the token as an
unknown word rather than a number.

## Location

`src/convert.S`, lines 112–118:

```asm
// check if the digit is A or more. if we get here, and it is, it is a bad digit
cmp r3,#'a'          // 'a' = 97; 'A' = 65
blt _myatoierrorpop  // anything < 'a' that got here is rejected — includes 'A'-'F'

// check if the digit is less than or equal to the limit specified by r5
cmp r3,r5
bgt _myatoierrorpop
```

`'A'` (65) is less than `'a'` (97), so uppercase hex digits branch to
`_myatoierrorpop`. The overflow flag is set, and the interpreter reports an error.

## Observed Behaviour

```forth
HEX 1a .    \ ok — prints 26
HEX 1A .    \ error — 1A not recognised as a number
```

## Fix

Normalise the digit to lowercase before the range check by folding `'A'–'Z'` to
`'a'–'z'`:

```asm
// after confirming digit > '9', fold to lowercase
cmp r3,#'A'
blt _myatoierrorpop   // below 'A' after passing '9' range — bad digit
cmp r3,#'Z'
bgt _checkLower       // above 'Z' — might be lowercase, check separately
add r3,#('a'-'A')     // fold uppercase to lowercase
_checkLower:
cmp r3,#'a'
blt _myatoierrorpop
cmp r3,r5
bgt _myatoierrorpop
```

Alternatively, unconditionally `or r3,#0x20` to fold any letter to lowercase
before the range check (safe because digits `'0'–'9'` are never in this branch).

## Workaround

Always type hex digits in lowercase: `HEX ff` not `HEX FF`.

## Severity

Low — a convention issue rather than a crash. Consistent lowercase hex input works
correctly. Uppercase input gives a confusing silent error.
