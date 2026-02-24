/*
 * SD card backend — Mbed SDBlockDevice (mbed-os 6.15.1) + FATFileSystem.
 *
 * Board: Olimex RP2040-PICO-PC rev D
 *   MOSI=GP7  MISO=GP4  CLK=GP6  CS=GP21
 *
 * SDBlockDevice source lives in the sibling repo ../mbed-sdblockdevice
 * (Apache-2.0, extracted from mbed-os 6.15.1).
 * FATFileSystem is compiled into RASPBERRY_PI_PICO/libs/libmbed.a.
 *
 * After sd_backend_init() succeeds, standard fopen("/sd/path", mode) routes
 * through FATFileSystem automatically via Mbed's filesystem path dispatch.
 */

#include "mbed_config.h"        /* MBED_CONF_* macros — must precede any Mbed header */
#include "sd_backend.h"
#include "SDBlockDevice.h"
#include <fat/FATFileSystem.h>
#include <stdio.h>
#include <string.h>

// ── Hardware ──────────────────────────────────────────────────────────────────
// SDBlockDevice(mosi, miso, sck, cs, hz)
static SDBlockDevice      sd_dev((PinName)7, (PinName)4, (PinName)6, (PinName)21,
                                  12500000);
static mbed::FATFileSystem sd_fs("sd");   // mounts as /sd/ in POSIX namespace

// ── State ─────────────────────────────────────────────────────────────────────
static FILE *open_files[VFS_MAX_FILES];

// ── Helpers ───────────────────────────────────────────────────────────────────
static const char *vfs_flags_to_mode(int flags)
{
    int rw = flags & (VFS_O_READ | VFS_O_WRITE);
    if (rw == (VFS_O_READ | VFS_O_WRITE))
        return (flags & VFS_O_TRUNC) ? "w+b" : "r+b";
    if (flags & VFS_O_WRITE)
        return (flags & VFS_O_TRUNC) ? "wb" : "ab";
    return "rb";
}

// ── VFS ops ───────────────────────────────────────────────────────────────────
static int sd_open(const char *path, int flags)
{
    char full[64];
    snprintf(full, sizeof(full), "/sd/%s", path);

    for (int i = 0; i < VFS_MAX_FILES; i++) {
        if (!open_files[i]) {
            open_files[i] = fopen(full, vfs_flags_to_mode(flags));
            if (open_files[i]) return i;
            return -1;
        }
    }
    return -1;
}

static void sd_close(int fd)
{
    if (fd < 0 || fd >= VFS_MAX_FILES || !open_files[fd]) return;
    fclose(open_files[fd]);
    open_files[fd] = NULL;
}

static int sd_read(int fd, void *buf, int len)
{
    if (fd < 0 || fd >= VFS_MAX_FILES || !open_files[fd]) return -1;
    return (int)fread(buf, 1, (size_t)len, open_files[fd]);
}

static int sd_write(int fd, const void *buf, int len)
{
    if (fd < 0 || fd >= VFS_MAX_FILES || !open_files[fd]) return -1;
    return (int)fwrite(buf, 1, (size_t)len, open_files[fd]);
}

static int sd_seek(int fd, int offset, int whence)
{
    if (fd < 0 || fd >= VFS_MAX_FILES || !open_files[fd]) return -1;
    return fseek(open_files[fd], (long)offset, whence);
}

static int sd_size(int fd)
{
    if (fd < 0 || fd >= VFS_MAX_FILES || !open_files[fd]) return -1;
    long cur  = ftell(open_files[fd]);
    fseek(open_files[fd], 0, SEEK_END);
    long size = ftell(open_files[fd]);
    fseek(open_files[fd], cur, SEEK_SET);
    return (int)size;
}

static int sd_unlink(const char *path)
{
    char full[64];
    snprintf(full, sizeof(full), "/sd/%s", path);
    return remove(full);
}

// ── Public interface ──────────────────────────────────────────────────────────
extern "C" const vfs_ops_t sd_ops = {
    .open   = sd_open,
    .close  = sd_close,
    .read   = sd_read,
    .write  = sd_write,
    .seek   = sd_seek,
    .size   = sd_size,
    .unlink = sd_unlink,
};

extern "C" int sd_backend_init(void)
{
    memset(open_files, 0, sizeof(open_files));
    int err = sd_dev.init();
    if (err) return err;
    return sd_fs.mount(&sd_dev);   /* 0 = success, negative = Mbed error */
}
