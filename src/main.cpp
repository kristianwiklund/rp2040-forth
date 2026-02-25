#include <Arduino.h>

#include "storage/vfs.h"
#include "storage/sd_backend.h"
#include "storage/ram_backend.h"
#include "storage/rom_backend.h"

extern "C" void forth();
extern "C" void flushinput();

// getchar/putchar used by the assembly words via bl getchar / bl putchar.
extern "C" int getchar(void) {
    while (!Serial.available()) { delay(1); }
    return Serial.read();
}

extern "C" int putchar(int c) {
    Serial.write((uint8_t)c);
    return c;
}

void setup() {
    Serial.begin(115200);
    // Wait for USB host to connect and open the port.
    while (!Serial) { delay(10); }
    delay(100);

    // Disable stdio buffering so printf output appears immediately.
    setvbuf(stdout, NULL, _IONBF, 0);

    // Initialise the VFS and register storage backends.
    vfs_init();
    rom_backend_init();
    vfs_register("/rom", &rom_ops);
    ram_backend_init();
    vfs_register("/ram", &ram_ops);

    if (sd_backend_init() == 0) {
        vfs_register("/sd", &sd_ops);
        printf("SD mounted\n");
    } else {
        printf("SD mount failed (no card or SPI wiring issue)\n");
    }

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
    while (Serial.available()) {
        Serial.read();
    }
}

void loop() {}
