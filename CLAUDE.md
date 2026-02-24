# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Forth interpreter for the RP2040 (Raspberry Pi Pico) written in ARM Thumb assembly, with an in-progress STM32F103 port. It is a learning project for ARM/RP2040 assembly — not intended to be a complete or production Forth.

**Known issues:** No error handling, hangs with USB serial (use UART), FIND may be broken.

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

The interpreter is a **threaded-code** Forth. Words are stored as linked list nodes in memory. Register **r5** is the Forth instruction pointer (IP), holding the address of the next word pointer to execute.

- `done` / `execute` (in `src/forth.S`): the inner interpreter loop. Reads the word pointer at r5, advances r5, and dispatches.
- Native (assembler) words jump directly to their ARM code.
- Forth-defined words are detected by `FLAG_FORTH_WORD` (0x10) in the header flags field. The interpreter saves r5 on the Forth frame stack and sets r5 to the exec ptr (start of the new word list).
- `DONE` macro: jumps back to `done` (the inner interpreter). Every assembler word ends with `DONE`.

### Register Conventions

| Register | Role | Save/restore? |
|---|---|---|
| r5 | IP (Forth instruction pointer) | Yes — any word using r5 as temp must save and restore it |
| r6 | DSP (data stack pointer) | No — dedicated, never save/restore |
| r7 | RSP (return/frame stack pointer) | No — dedicated, never save/restore |

### Word Header Layout (`themacros.h`)

Each word in the dictionary is a 16-byte-aligned struct:

```
[link ptr (4)] [flags (4)] [length (4)] [exec ptr (4)] [name (asciz)] [code...]
```

- `exec ptr == 0` → variable (pushes its own data address)
- `FLAG_FORTH_WORD` set in flags → Forth-defined word (exec ptr points at first word pointer in a `0`-terminated list)
- otherwise → ARM assembler code (native word)

Offsets: `OFFSET_FLAGS=4`, `OFFSET_LENGTH=8`, `OFFSET_EXEC=12`, `OFFSET_NAME=16`.

### Key Macros (`src/themacros.h`)

| Macro | Purpose |
|---|---|
| `HEADER word, len, flags, label` | Define a native assembler word |
| `FHEADER word, len, flags, label` | Define a Forth-defined word (sets `FLAG_FORTH_WORD` in flags) |
| `RAWHEADER` | Low-level header without extra flags |
| `KPUSH` / `KPOP` | Push/pop the data stack — inline macros operating on r0, using r6 as DSP |
| `CFPUSH reg` / `CFPOP reg` | Push/pop the Forth frame (return) stack, using r7 as RSP |
| `DONE` | Jump to inner interpreter (`done`) |
| `CONSTANT` / `VARIABLE` | Convenience macros for declaring constants/variables |

### Stacks

- **Value stack**: software-managed in `.data` (`stackbottom`…`stacktop`), pointer in **r6** (DSP, dedicated register). Grows downward.
- **Frame/return stack**: software-managed (`forthframestackstart`…`forthframestackend`), pointer in **r7** (RSP, dedicated register). Used for Forth call/return and `>R`/`R>`.
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
| `src/main.cpp` | Arduino entry point — calls `vfs_init()` then `forth()` from `setup()` |
| `src/hardware/` | Minimal RP2040 register headers |
| `src/filewords.h` | File I/O Forth words: `INCLUDE`, `OPEN-FILE`, `CLOSE-FILE`, `READ-FILE`, `WRITE-FILE`, `FILE-SIZE` |
| `src/storage/vfs.h` | VFS C interface: `vfs_ops_t`, `vfs_register`, `vfs_open/close/read/write/seek/size/unlink` |
| `src/storage/vfs.c` | VFS mount registry and global fd-table dispatch |
| `src/storage/sd_backend.cpp/.h` | SD card backend stub (returns -1; see docs/storage.md for viable upgrade paths); exposes `sd_ops` and `sd_backend_init()` |
| `src/storage/ram_backend.c/.h` | Named SRAM buffer slots; exposes `ram_ops` and `ram_create()` |
| `src/storage/rom_backend.c/.h` | Read-only rodata blobs (`/rom/boot.fth`); exposes `rom_ops` |
| `src/storage/lfs_backend.h` | LittleFS stub — all-NULL `lfs_ops`; no `.c` yet |

### Boot Sequence

1. `main.cpp` `setup()` calls `forth()`.
2. `forth()` (`forth.S`) initializes r5 (IP) to `=boot`, r6 to `stacktop`, r7 to `forthframestackend`.
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
