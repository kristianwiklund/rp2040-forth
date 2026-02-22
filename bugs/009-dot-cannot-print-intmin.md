# Bug 009: `.` produces garbled output for `INT_MIN` (−2147483648)

## Test

**12.2** — `2147483647 1 + .`
Got: `- <garbled bytes>`  Expected: `-2147483648`

## Summary

Printing the minimum 32-bit signed integer (−2147483648 = 0x80000000) fails
inside `myitoa` (`src/convert.S`).  The standard approach to convert a negative
number is to negate it, convert the absolute value to digits, then prepend `−`.
For `INT_MIN`, negation overflows: `−(−2147483648) = 2147483648` does not fit
in a signed 32-bit register; the ARM result is `0x80000000` again (the
original value), producing an infinite loop or incorrect digit extraction that
writes garbage bytes to `wordbuf2`.

## Location

`src/convert.S` — `myitoa` / number-to-string conversion routine.

## Severity

Low — only triggered by exactly `INT_MIN`; all other negative values print
correctly.
