# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Forth interpreter for the RP2040 (Raspberry Pi Pico) written in ARM Thumb assembly, with an in-progress STM32F103 port. It is a learning project for ARM/RP2040 assembly — not intended to be a complete or production Forth.

**Known issues:** No error handling, hangs with USB serial (use UART), some words broken (EXECUTE, FIND).

## Build & Flash

The primary build system is PlatformIO:

```sh
make          # build (pio run)
make upload   # build and flash via picoprobe/cmsis-dap
make clean    # clean build artifacts
make serial   # open serial connection
make gdb      # launch gdb-multiarch on the built ELF
```

There is also an older `CMakeLists.txt` for the Pico SDK (not the active path — `platformio.ini` is what's used).

The STM32F103 target has its own `stm32f103/Makefile`.

## Architecture

### Execution Model

The interpreter is a **threaded-code** Forth. Words are stored as linked list nodes in memory. The `wordptr` global tracks the current execution pointer (analogous to Forth's IP — instruction pointer).

- `done` / `execute` (in `src/forth.S`): the inner interpreter loop. Reads the word at `wordptr`, advances `wordptr`, and dispatches.
- Native (assembler) words jump directly to their ARM code.
- Forth-defined words are detected by the magic sentinel `0xabadbeef` at the start of their code field. The interpreter saves the return address on the Forth frame stack and starts executing the new word list.
- `DONE` macro: jumps back to `done` (the inner interpreter). Every assembler word ends with `DONE`.

### Word Header Layout (`themacros.h`)

Each word in the dictionary is a 16-byte-aligned struct:

```
[link ptr (4)] [flags (4)] [length (4)] [exec ptr (4)] [name (asciz)] [code...]
```

- `exec ptr == 0` → variable (pushes its own data address)
- `exec ptr → 0xabadbeef` → Forth-defined word (list of word pointers + `0` terminator)
- otherwise → ARM assembler code

Offsets: `OFFSET_FLAGS=4`, `OFFSET_LENGTH=8`, `OFFSET_EXEC=12`, `OFFSET_NAME=16`.

### Key Macros (`src/themacros.h`)

| Macro | Purpose |
|---|---|
| `HEADER word, len, flags, label` | Define a native assembler word |
| `FHEADER word, len, flags, label` | Define a Forth-defined word (adds `0xabadbeef` marker) |
| `RAWHEADER` | Low-level header without the marker |
| `KPUSH` / `KPOP` | Push/pop the value (data) stack (calls `_kpush`/`_kpop`, operate on `r0`) |
| `CFPUSH reg` / `CFPOP reg` | Push/pop the Forth frame (return) stack |
| `DONE` | Jump to inner interpreter (`done`) |
| `CONSTANT` / `VARIABLE` | Convenience macros for declaring constants/variables |

### Stacks

- **Value stack**: software-managed in `.data` (`stackbottom`…`stacktop`), pointer at `vstackptr`. Grows downward.
- **Frame/return stack**: software-managed (`forthframestackstart`…`forthframestackend`), pointer at `forthframestackptr`. Used for Forth call/return and `>R`/`R>`.
- **CPU stack**: ARM `sp`, used within individual word implementations.

### Source Files

| File | Contents |
|---|---|
| `src/forth.S` | Entry point, inner interpreter, FIND, INTERPRET, stack ops, data section |
| `src/themacros.h` | All assembly macros and word header constants |
| `src/compile.h` | Compile-time words: `:`, `;`, `CREATE`, `LIT`, `'`, `HERE`, `@`, `!`, `SEE`, `0BRANCH`, `BRANCH`, `IMMEDIATE`, `[`, `]` |
| `src/terminal.h` | Input words: `KEY`, `WORD`, `FLUSHSTDIN`, `READ-LINE` |
| `src/output.h` | Output words: `.`, `EMIT`, `TYPE`, `S"` |
| `src/mathwords.h` | Arithmetic/comparison words |
| `src/strings.S` | String helpers (`mymemcpy`, `myatoi`, etc.) |
| `src/helpers.S` | Miscellaneous helpers (`alignhelper`, etc.) |
| `src/forthdefs.h` | Forth words defined in ASCII Forth source, interpreted at boot (`ROT`, `SWAP`, `OVER`, `IF`/`THEN`/`ELSE`, `BEGIN`/`UNTIL`, `:`, `;`, etc.) |
| `src/convert.S` | Number conversion helpers |
| `src/main.cpp` | Arduino entry point — calls `forth()` from `setup()` |
| `src/hardware/` | Minimal RP2040 register headers |

### Boot Sequence

1. `main.cpp` `setup()` calls `forth()`.
2. `forth()` (`forth.S`) initializes globals, sets `wordptr` to the `boot` list.
3. `boot` list: `FLUSHSTDIN → INTERPRET → END`.
4. `INTERPRET` reads from `inputptr`, which starts pointing at `forthdefs` (the ASCII Forth source compiled in via `.ascii`/`.asciz`).
5. After `forthdefs` is exhausted, `INTERPRET` reads from the UART.

### Adding a New Assembler Word

```asm
HEADER "MYWORD", 6, 0, MYWORD   @ name, length, flags, label
    @ implementation using KPOP/KPUSH for stack ops
    KPOP                          @ r0 = top of stack
    @ ... do something with r0 ...
    KPUSH                         @ push r0 onto stack
    DONE
```

### Adding a New Forth Word

Add a `.ascii` line to `src/forthdefs.h` (before the final `.asciz` line):
```c
.ascii ": MYWORD ... ; "
```

### Documentation Convention

Inline word documentation uses `#:` comments (parsed by `scripts/gendocs.sh`):
```asm
#: MYWORD (a b -- c) ; description
```
