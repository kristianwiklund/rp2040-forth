# Bug 018: `READ-FILE` test word not executed — device echoes definition back

## Summary

Test 14.5: defining and calling a word that opens `/rom/boot.fth`, reads 4 bytes,
and prints the byte count does not produce the expected output. The device echoes
the word body back instead of executing the compiled word.

## Test

```
14.5  READ-FILE: request 4 bytes, receive 4
```

Input sent:
```forth
: T14E S" /rom/boot.fth" 0 1 OPEN-FILE DROP DUP HERE 4 ROT READ-FILE DROP SWAP CLOSE-FILE DROP . ; T14E
```

Expected output:
```
4
```

## Observed Behaviour

```
<<T14E>> S" /rom/boot.fth" 0 1 OPEN-FILE DROP DUP HERE 4 ROT READ-FILE DROP SWAP CLOSE-FILE DROP . ; T14E ?
(c):
```

The device echoed the word body starting from the word name `T14E`, followed
by a `?` and a compile-mode prompt. The expected result `4 ` was not printed.
