# Bug 016: `CLOSE-FILE` test word not executed — device echoes definition back

## Summary

Test 14.3: defining and calling a word that opens `/rom/boot.fth` and closes it
does not produce the expected output. The device echoes the word body back
instead of executing the compiled word.

## Test

```
14.3  CLOSE-FILE returns ior=0
```

Input sent:
```forth
: T14C S" /rom/boot.fth" 0 1 OPEN-FILE DROP CLOSE-FILE . ; T14C
```

Expected output:
```
0
```

## Observed Behaviour

```
<<T14C>> S" /rom/boot.fth" 0 1 OPEN-FILE DROP CLOSE-FILE . ; T14C ?
(c):
```

The device echoed the word body starting from the word name `T14C`, followed
by a `?` and a compile-mode prompt. The expected result `0 ` was not printed.
