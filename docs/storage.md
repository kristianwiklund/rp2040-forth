# Storage System Architecture

## Hardware

Board: **Olimex RP2040-PICO-PC** (rev D carrier for Raspberry Pi Pico).

SD card slot wired via **SPI0**:

| Signal | GPIO | Notes |
|--------|------|-------|
| MISO   | GP4  | SPI0 RX |
| CLK    | GP6  | SPI0 SCK |
| MOSI   | GP7  | SPI0 TX |
| CS     | GP21 | Active low |

Verified from rev D netlist. No card-detect pin is wired.

---

## VFS Abstraction Layer

All file I/O goes through a thin virtual filesystem layer in `src/storage/vfs.h` / `vfs.c`.

### Rationale

Isolating the Forth word layer from the storage backend means:

- The `INCLUDE`, `OPEN-FILE`, `LOAD` etc. words never reference FatFs or Mbed directly.
- Swapping to LittleFS (for wear levelling on on-board flash) requires only plugging in
  a new `vfs_ops_t` struct — no changes to any Forth word or the interpreter.
- The RAM and ROM backends let the system work without SD hardware present.

### Mount Point Convention

| Prefix | Backend | Notes |
|--------|---------|-------|
| `/sd`  | FatFs on SPI0 SD card | Primary persistent storage |
| `/ram` | SRAM named slots | Volatile; useful for testing without SD |
| `/rom` | Rodata blobs in flash | Read-only; `boot.fth` = forthdefs |
| `/lfs` | LittleFS (stub) | Future: wear-levelled on-chip flash |

`vfs_register("/sd", &sd_ops)` is called in `main.cpp` → `vfs_init()`.
Prefix matching uses longest-prefix-wins. Paths like `/sd/dir/file.fth` strip the
`/sd` prefix before passing `dir/file.fth` to FatFs as `0:/dir/file.fth`.

---

## Architecture Diagram

```
Forth words (INCLUDE, OPEN-FILE, LOAD …)
        │
        ▼
   vfs.h / vfs.c          ← single dispatch layer
        │
   path prefix routing
   /sd/  /ram/  /rom/  /lfs/
    │      │      │      │
 sd_ops  ram_ops rom_ops lfs_ops (stub)
 FatFs   SRAM   rodata   (future LittleFS)
 SPI0    slots   blobs
```

Internal fd table: `{ uint8_t mount_idx; int backend_fd; }[VFS_MAX_FILES]`.
Global fds are 1-based (0 = error).

---

## Source Files

| File | Role |
|------|------|
| `src/storage/vfs.h` | C interface: `vfs_ops_t`, `vfs_register`, `vfs_open/close/read/write/seek/size/unlink` |
| `src/storage/vfs.c` | Mount registry + global fd table dispatch |
| `src/storage/sd_backend.cpp/.h` | SD backend; currently a stub (returns -1) |
| `src/storage/ram_backend.c/.h` | Named SRAM buffer slots; exposes `const vfs_ops_t ram_ops` |
| `src/storage/rom_backend.c/.h` | Read-only rodata blobs; exposes `const vfs_ops_t rom_ops` |
| `src/storage/lfs_backend.h` | Stub — all-NULL `vfs_ops_t lfs_ops`; no `.c` yet |
| `src/filewords.h` | All storage Forth words (`INCLUDE`, `OPEN-FILE`, etc.) |

---

## SD Backend

**Current state**: `sd_backend.cpp` is a stub; `sd_backend_init()` returns -1 and
`/sd` is never registered. The system falls back gracefully to `/rom` and `/ram`.

### Libraries investigated — all failed under Arduino+Mbed

The project uses **Arduino+Mbed** (maxgerhardt `platform-raspberrypi`,
`framework-arduino-mbed` v4.4.1). Three SD libraries were investigated:

| Library | Failure reason |
|---------|---------------|
| **greiman/SdFat** | Unconditionally defines `HAS_PIO_SDIO=1` in `SdFatConfig.h` (no `#ifndef` guard), which pulls in bare Pico SDK types (`PIO`, `pio_sm_config`) that do not exist under Mbed. Flag overrides on the command line have no effect. |
| **Mbed SDBlockDevice** (`COMPONENT_SD`) | Header exists at `COMPONENT_SD/include/SD/SDBlockDevice.h` but there is no `SDBlockDevice.cpp` in the framework install and no `SDBlockDevice.o` in `RASPBERRY_PI_PICO/libs/libmbed.a`. Nothing to link against. |
| **carlk3/no-OS-FatFS** | Targets bare Pico SDK; its `hw_config` system assumes Pico SDK types. Incompatible with Arduino+Mbed. |

### Viable forward paths

**`FATFileSystem.o` IS compiled into the Pico `libmbed.a`** — ChaN FatFs is
available. The missing piece is a block device that speaks SPI SD.

**Path A — Source SDBlockDevice.cpp from mbed-os**

The mbed-os 6.15.x source has a `SDBlockDevice.cpp` that implements the SPI SD
protocol against `mbed::SPI` + `mbed::DigitalOut` (no PIO, no Pico SDK types).
Steps:
1. Download `SDBlockDevice.cpp` from
   `github.com/ARMmbed/mbed-os` tag `mbed-os-6.15.1`,
   path `storage/blockdevice/COMPONENT_SD/source/SDBlockDevice.cpp`.
2. Place it in `src/storage/SDBlockDevice.cpp`.
3. Add to `platformio.ini` `build_flags`:
   ```
   "-I${platformio.packages_dir}/framework-arduino-mbed/cores/arduino/mbed/storage/blockdevice/COMPONENT_SD/include"
   "-I${platformio.packages_dir}/framework-arduino-mbed/cores/arduino/mbed/storage/filesystem/fat/include"
   ```
4. Rewrite `sd_backend.cpp` to instantiate `SDBlockDevice` + `mbed::FATFileSystem`
   and use `fopen("/sd/path", mode)` / `fread` / `fwrite` etc. (Mbed retargets
   `/sd/...` through the filesystem tree automatically).

**Path B — Switch to Earle Philhower Arduino core**

Replace the Mbed framework with `board_build.core = earlephilhower` in
`platformio.ini` (the maxgerhardt platform already ships the Earle core).
Under Earle's core:
- `greiman/SdFat` compiles cleanly — the bare Pico SDK types it needs are present.
- `_SerialUSB` → `Serial` in `main.cpp`; `mbed_override_console` and the RTOS
  yield trick (`delay(1)`) are removed.
- All assembly (`forth.S`) and the VFS layer (`vfs.c`, backends) are unaffected.

Path B is the lower-friction long-term choice; Path A stays on Mbed.

---

## ROM Backend

Named blobs in `.rodata`. `boot.fth` exposes the `forthdefs` bootstrap source
as a readable VFS file at `/rom/boot.fth`.

The assembly adds `forthdefs_end` label after the forthdefs include so the C
code can calculate `forthdefs_end - forthdefs` = size in bytes.

---

## RAM Backend

Fixed table of named SRAM slots (16 bytes name + data pointer + capacity + length).
Static pool: 2 KB reserved in `ram_backend.c` — carved from a static array,
not from the Forth heap, to avoid interfering with dictionary allocation.

Forth interaction: `INCLUDE /ram/foo.fth` reads a slot. A future `RAM-CREATE`
word writes a slot for testing without SD hardware.

---

## Input Source Stack

When `INCLUDE` opens a file, it pushes an entry on a small stack in `.data`:

```
input_source_sp:    .int  0       // stack depth; 0 = empty (UART/bootstrap)
input_source_stack: .space 64     // 8 entries × 8 bytes each
                                  // each entry: { int32 source_id, int32 vfs_fd }
```

`mygetchar()` checks `input_source_sp` first. If >0, it reads one byte via
`vfs_read`. On EOF it closes the fd and decrements the depth. When the stack
empties, the original inputptr/buffer/UART path resumes.

Nesting depth: up to 8 levels (stack depth = 8 entries).

---

## Phased Word Implementation

| Sprint | Words Added | Notes |
|--------|------------|-------|
| 6 | (none) | VFS + SD backend wired; verified by `printf` listing SD root |
| 7 | `INCLUDE` | Native word; pushes file source; interpreter draws from file transparently |
| 8 | `OPEN-FILE` `CLOSE-FILE` `READ-FILE` `WRITE-FILE` `FILE-SIZE` | ANS file words; `ior=0` on success |
| 9 | `BLOCK` `BUFFER` `UPDATE` `FLUSH` `LOAD` `THRU` | Block word set; 1 KB buffer in `.data` |
| 10 | `SAVE-IMAGE` `LOAD-IMAGE` | Dictionary image to/from SD; warm start on boot |
| — | `EVALUATE` `RAM-CREATE` `DELETE-FILE` | Deferred; trivial once Sprint 7 exists |

---

## RAM Budget

| Addition | Size |
|----------|------|
| FatFs FIL structs ×8 | ~720 B |
| VFS fd + mount tables | ~70 B |
| Input source stack | 64 B |
| Block buffer (Sprint 9) | 1024 B |
| RAM filesystem pool | 2048 B |
| **Total new** | **~3.9 KB** |

Current allocation ~9.5 KB used; RP2040 has 264 KB SRAM total. Comfortable.

---

## Backend Comparison

| Property | FatFs (SD, SPI) | LittleFS (on-chip flash) |
|----------|----------------|--------------------------|
| Media | SD card (removable) | RP2040 internal flash |
| Wear levelling | None (relies on card) | Yes (built in) |
| FAT compatibility | Yes — readable on PC | No |
| Access speed | SPI-limited (~12 Mb/s) | XIP-limited but fast reads |
| Sprint | 6–7 | Deferred |

SPI0 at 12.5 MHz gives ~1.5 MB/s throughput — adequate for text file includes.

---

## Sprint 6 Verification

```
// In setup(), after vfs_init():
int fd = vfs_open("/sd/test.txt", VFS_O_READ);
if (fd) {
    char buf[64];
    int n = vfs_read(fd, buf, sizeof(buf)-1);
    buf[n] = '\0';
    printf("SD test: %s\n", buf);
    vfs_close(fd);
} else {
    printf("SD open failed\n");
}
```

Confirms SPI wiring and FatFs stack before any Forth words are involved.

## Sprint 7 Verification

Put on SD card:
```forth
: HI 72 EMIT ;
```

From Forth REPL:
```
INCLUDE /sd/hello.fth
HI
```

Expected output: `H`
