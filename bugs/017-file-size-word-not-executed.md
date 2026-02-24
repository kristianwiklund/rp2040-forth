# Bug 017: `FILE-SIZE` test word not executed — device echoes definition back

## Summary

Test 14.4: defining and calling a word that opens `/rom/boot.fth` and checks its
size does not produce the expected output. The device echoes the word body back
instead of executing the compiled word.

## Test

```
14.4  FILE-SIZE on /rom/boot.fth returns positive size
```

Input sent:
```forth
: T14D S" /rom/boot.fth" 0 1 OPEN-FILE DROP DUP FILE-SIZE DROP 0 > SWAP CLOSE-FILE DROP . ; T14D
```

Expected output:
```
1
```

## Observed Behaviour

```
<<T14D>> S" /rom/boot.fth" 0 1 OPEN-FILE DROP DUP FILE-SIZE DROP 0 > SWAP CLOSE-FILE DROP . ; T14D ?
(c):
```

The device echoed the word body starting from the word name `T14D`, followed
by a `?` and a compile-mode prompt. The expected result `1 ` was not printed.
