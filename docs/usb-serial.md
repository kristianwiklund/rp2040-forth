# USB CDC Serial

## Stack Overview

The build uses `framework-arduino-mbed` (mbed RTOS-based Arduino core for RP2040).
The USB CDC stack is mbed's RTOS-threaded implementation — **not** TinyUSB. Key
objects:

- `_SerialUSB` — global `arduino::USBSerial` instance declared in
  `<USB/PluggableUSBSerial.h>`. Wraps `USBCDC` which runs on a dedicated mbed
  RTOS thread.
- `_SerialUSB.connected()` — returns true when a USB host has opened the port
  (DTR asserted). Must be true before reading or writing or data is lost/stale.
- `_SerialUSB.available()` — bytes waiting in the USB RX ring buffer.
- `_SerialUSB.read()` — non-blocking; returns -1 if buffer empty.
- `_SerialUSB.write(uint8_t)` — non-blocking fire-and-forget TX.

The board variant (`RASPBERRY_PI_PICO/pins_arduino.h`) already defines
`SERIAL_CDC=1`. No platformio.ini build flag is needed for USB CDC.

## C stdio Routing

mbed retargets C stdio (`printf`, `getchar`, `putchar`, `fprintf`) through a
`FileHandle` abstraction. By default it falls back to `UnbufferedSerial` on the
hardware UART (GP0/GP1). The routing is controlled by a **weak symbol**:

```cpp
namespace mbed {
    FileHandle *mbed_override_console(int fd);  // weak in libmbed.a
}
```

Overriding this in application code redirects all three standard streams
(fd 0=stdin, 1=stdout, 2=stderr) to any `FileHandle*`. We return `&_SerialUSB`
to send all stdio to USB CDC.

This override alone is sufficient for `printf`/`fprintf` (TX path). The TX path
is fire-and-forget: `_putc` → `USBSerial::write()` → `USBCDC::send()`, which
queues packets and returns immediately without waiting on any RTOS primitive.

## Why getchar Hung (RTOS Scheduling)

The RX path is different. The unmodified mbed `getchar` path:

```
getchar() → fgetc(stdin) → mbed retarget _read(0, buf, 1)
         → FileHandle::read() → USBSerial::_getc()
         → USBCDC::receive() → rtos semaphore wait
```

`USBCDC::receive()` blocks by waiting on an RTOS semaphore. That semaphore is
posted by the USB RX RTOS thread (`rtos::Thread* t` inside `USBSerial`) when
a USB packet arrives and is drained into the ring buffer.

**The problem:** `forth()` is called from `setup()` and never returns. The Forth
interpreter spins in a tight character-by-character read loop. This loop never
yields to the RTOS scheduler, so the USB RX thread never gets CPU time, never
drains incoming USB packets, and never posts the semaphore. `getchar` therefore
blocks forever even if the host is sending data.

This did **not** affect TX (`printf`/`putchar`) because the TX path has no
semaphore wait — output appeared over USB while input was stuck.

## Fix: Custom getchar/putchar

The fix is to bypass mbed retargeting entirely for `getchar` and `putchar`.
`getchar` and `putchar` are **weak symbols** in newlib (the ARM GCC C runtime).
Defining them as `extern "C"` in `main.cpp` overrides the library versions at
link time.

```cpp
extern "C" int getchar(void) {
    while (!_SerialUSB.connected()) { /* spin on reconnect */ }
    while (!_SerialUSB.available()) { delay(1); }
    return _SerialUSB.read();
}

extern "C" int putchar(int c) {
    if (!_SerialUSB.connected()) return c;
    _SerialUSB.write((uint8_t)c);
    return c;
}
```

The `delay(1)` in the `available()` busy-wait is essential. `delay()` calls
`rtos::ThisThread::sleep_for(1ms)`, which yields to the scheduler and allows the
USB RX RTOS thread to run, drain the incoming USB packet into the ring buffer,
and make `available()` return non-zero.

A bare spin (`while (!available()) {}`) would still starve the USB RX thread and
hang identically to the original bug.

`printf` still works via `mbed_override_console` returning `&_SerialUSB` —
`printf` uses `_write()` not `putchar` internally, so both paths are covered.

## Startup Sequence

```cpp
void setup() {
    while (!_SerialUSB.connected()) { delay(10); }  // wait for DTR
    delay(100);                                      // settling time
    printf("Forth/RP2040 ready\n");
    forth();
}
```

Entering Forth before `connected()` is true causes:
- `printf` output silently dropped (USBCDC send guard checks `_terminal_connected`)
- `getchar` to spin forever in the `connected()` guard inside our custom override

## flushinput()

`flushinput()` is called from the `FLUSHSTDIN` Forth word and from
`readlinehelper` after receiving a newline (to discard any trailing bytes, e.g.
the `\r` of a `\r\n` pair). It was previously an empty stub.

```cpp
void flushinput() {
    while (_SerialUSB.available()) {
        _SerialUSB.read();
    }
}
```

## Known Issue: Disconnect Mid-Session

If the USB host disconnects while Forth is running:
- `putchar` returns silently (guarded by `connected()` check).
- `getchar` spins forever in `while (!_SerialUSB.connected())`.

This is a better outcome than the original (which would corrupt the input
buffer with `-1` → `0xFF`), but the interpreter will hang until the host
reconnects and reasserts DTR.

A future improvement: after reconnect, flush the input buffer and re-print the
prompt so the session resumes cleanly.

## Known Issue: -1 from getchar in mygetchar

The `mygetchar` function in `src/terminal.h` reads from the `inputptr`/`buffer`
ring and calls `readlinehelper` (which calls `getchar`) when the buffer is empty.
`mygetchar` does not check for a `-1` return from `getchar`. If `-1` ever
reaches `mygetchar` (e.g. via an alternative code path), it wraps to `0xFF` as
a `uint8_t` and is treated as a printable character, corrupting the input buffer.

With the current custom `getchar` this path is not reachable during normal
operation, but it remains a latent fragility worth fixing.

## GDB Diagnostics (with debug probe)

If input hangs after flashing:

```
# Confirm the linker picked up the custom getchar (not mbed's)
(gdb) info symbol getchar

# Break at the input loop and check registers
(gdb) break readlinehelper
(gdb) continue
(gdb) stepi   # step into bl getchar — should land in main.cpp

# Check USB RX state
(gdb) print _SerialUSB.connected()
(gdb) print _SerialUSB.available()

# Check Forth register sanity (r6=DSP, r7=RSP must be in .data stack regions)
(gdb) info registers r5 r6 r7
```
