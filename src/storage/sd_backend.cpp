/*
 * SD card backend — stub.
 *
 * Board: Olimex RP2040-PICO-PC rev D
 *   MOSI=GP7  MISO=GP4  CLK=GP6  CS=GP21
 *
 * No SD library has been found that compiles cleanly under Arduino-Mbed for RP2040.
 * sd_backend_init() always returns -1 so /sd is never registered.
 */

#include "sd_backend.h"
#include <string.h>

static int stub_open   (const char *, int)          { return -1; }
static void stub_close (int)                         { }
static int stub_read   (int, void *, int)            { return -1; }
static int stub_write  (int, const void *, int)      { return -1; }
static int stub_seek   (int, int, int)               { return -1; }
static int stub_size   (int)                         { return -1; }
static int stub_unlink (const char *)                { return -1; }

extern "C" const vfs_ops_t sd_ops = {
    .open   = stub_open,
    .close  = stub_close,
    .read   = stub_read,
    .write  = stub_write,
    .seek   = stub_seek,
    .size   = stub_size,
    .unlink = stub_unlink,
};

extern "C" int sd_backend_init(void)
{
    return -1;   /* no SD library available for this target */
}
