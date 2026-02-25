#include <Arduino.h>
#include <USB/PluggableUSBSerial.h>
#include <platform/FileHandle.h>

#include "storage/vfs.h"
#include "storage/sd_backend.h"
#include "storage/ram_backend.h"
#include "storage/rom_backend.h"

extern "C" void forth();
extern "C" void flushinput();

// Redirect mbed C stdio (printf/fprintf) to USB CDC instead of UART.
namespace mbed {
FileHandle *mbed_override_console(int fd) {
    return &_SerialUSB;
}
}

// Custom getchar/putchar that bypass mbed retargeting + RTOS semaphore scheduling.
//
// The assembly words call these directly via bl getchar / bl putchar.
// Without this override, getchar uses an RTOS semaphore that the USB RX thread
// posts to — but that thread never gets scheduled while Forth spins in setup().
// The delay(1) inside the busy-wait yields to the RTOS so the USB RX thread runs.
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

void setup() {
    // Wait until a USB host connects and opens the port (DTR asserted).
    while (!_SerialUSB.connected()) {
        delay(10);
    }
    delay(100);

    // Disable stdio buffering so printf output appears immediately (no newline needed).
    setvbuf(stdout, NULL, _IONBF, 0);

    // Initialise the VFS and register storage backends.
    vfs_init();
    rom_backend_init();
    vfs_register("/rom", &rom_ops);
    ram_backend_init();
    vfs_register("/ram", &ram_ops);

    // ##### marks the start and stop of the area that causes the crash
    // #####
    // testing points at sd_backend_init being the root cause of the crash
    
    if (sd_backend_init() == 0) {
        vfs_register("/sd", &sd_ops);
        printf("SD mounted\n");
    } else {
        printf("SD mount failed (no card or SPI wiring issue)\n");
    }

    // #####    
    

#ifdef STOCK_SPRINT6_VERIFY
    {   /* Put test.txt on the SD card before booting. */
        int fd = vfs_open("/sd/test.txt", VFS_O_READ);
        if (fd) {
            char buf[64]; int n = vfs_read(fd, buf, 63);
            buf[n > 0 ? n : 0] = '\0';
            printf("SD verify: [%s]\n", buf);
            vfs_close(fd);
        } else { printf("SD verify: open failed\n"); }
    }
#endif

    printf("Forth/RP2040 ready\n");
    forth();
}

void flushinput() {
    while (_SerialUSB.available()) {
        _SerialUSB.read();
    }
}

void loop() {}
