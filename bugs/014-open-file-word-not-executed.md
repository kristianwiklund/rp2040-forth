# Bug 014: `OPEN-FILE` test word not executed — device echoes definition back

## Summary

Test 14.1: defining and immediately calling a word that uses `S"` and `OPEN-FILE`
does not produce the expected output. The device echoes the word body back to the
terminal instead of executing the compiled word.

## Test

```
14.1  OPEN-FILE on /rom/boot.fth: ior=0
```

Input sent:
```forth
: T14A S" /rom/boot.fth" 0 1 OPEN-FILE SWAP DROP 0 = . ; T14A
```

Expected output:
```
1
```

## Observed Behaviour

```
<</rom/boot.fth">> 0 1 OPEN-FILE SWAP DROP 0 = . ; T14A ?
(c):
```

The device did not print `1 `. Instead it appears to echo back part of the
word definition starting from the string literal content, followed by a `?`
(unknown word) and a compile-mode prompt.
