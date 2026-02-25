/*
 * SD card backend — carlk3 FatFs_SPI (Apache-2.0 + BSD FatFS)
 *
 * Board: Olimex RP2040-PICO-PC rev D
 *   MOSI=GP7  MISO=GP4  CLK=GP6  CS=GP21
 *
 * Hardware config is in sd_hw_config.c.  This file implements the VFS ops
 * using the FatFS f_open/f_read/… API; the vfs_ops_t interface is unchanged.
 *
 * Path convention: VFS strips the "/sd" prefix and leading "/" before calling
 * the backend, so sd_open receives "test.txt", not "/sd/test.txt".
 * We prepend "0:/" for FatFS.
 */

#include "sd_backend.h"
#include "hw_config.h"  /* sd_get_by_num, sd_card_t */
#include "ff.h"         /* FatFS API */
#include <stdio.h>
#include <string.h>

// ── State ─────────────────────────────────────────────────────────────────────

static FIL open_files[VFS_MAX_FILES];
static bool file_open[VFS_MAX_FILES];

// ── Helpers ───────────────────────────────────────────────────────────────────

static BYTE vfs_flags_to_fatfs_mode(int flags)
{
    int rw = flags & (VFS_O_READ | VFS_O_WRITE);
    if (rw == (VFS_O_READ | VFS_O_WRITE))
        return (flags & VFS_O_TRUNC) ? FA_READ | FA_WRITE | FA_CREATE_ALWAYS
                                     : FA_READ | FA_WRITE | FA_OPEN_EXISTING;
    if (flags & VFS_O_WRITE)
        return (flags & VFS_O_TRUNC) ? FA_WRITE | FA_CREATE_ALWAYS
                                     : FA_WRITE | FA_OPEN_APPEND;
    return FA_READ;
}

// ── VFS ops ───────────────────────────────────────────────────────────────────

static int sd_open(const char *path, int flags)
{
    char full[72];
    snprintf(full, sizeof(full), "0:/%s", path);

    for (int i = 0; i < VFS_MAX_FILES; i++) {
        if (!file_open[i]) {
            FRESULT rc = f_open(&open_files[i], full,
                                vfs_flags_to_fatfs_mode(flags));
            if (rc == FR_OK) {
                file_open[i] = true;
                return i;
            }
            return -1;
        }
    }
    return -1;
}

static void sd_close(int fd)
{
    if (fd < 0 || fd >= VFS_MAX_FILES || !file_open[fd]) return;
    f_close(&open_files[fd]);
    file_open[fd] = false;
}

static int sd_read(int fd, void *buf, int len)
{
    if (fd < 0 || fd >= VFS_MAX_FILES || !file_open[fd]) return -1;
    UINT br = 0;
    FRESULT rc = f_read(&open_files[fd], buf, (UINT)len, &br);
    if (rc != FR_OK) return -1;
    return (int)br;
}

static int sd_write(int fd, const void *buf, int len)
{
    if (fd < 0 || fd >= VFS_MAX_FILES || !file_open[fd]) return -1;
    UINT bw = 0;
    FRESULT rc = f_write(&open_files[fd], buf, (UINT)len, &bw);
    if (rc != FR_OK) return -1;
    return (int)bw;
}

static int sd_seek(int fd, int offset, int whence)
{
    if (fd < 0 || fd >= VFS_MAX_FILES || !file_open[fd]) return -1;
    FIL *fp = &open_files[fd];
    FSIZE_t target;
    switch (whence) {
        case 0: target = (FSIZE_t)offset; break;                        /* SET */
        case 1: target = f_tell(fp) + (FSIZE_t)offset; break;           /* CUR */
        case 2: target = f_size(fp) + (FSIZE_t)offset; break;           /* END */
        default: return -1;
    }
    return (f_lseek(fp, target) == FR_OK) ? 0 : -1;
}

static int sd_size(int fd)
{
    if (fd < 0 || fd >= VFS_MAX_FILES || !file_open[fd]) return -1;
    return (int)f_size(&open_files[fd]);
}

static int sd_unlink(const char *path)
{
    char full[72];
    snprintf(full, sizeof(full), "0:/%s", path);
    return (f_unlink(full) == FR_OK) ? 0 : -1;
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
    memset(file_open, 0, sizeof(file_open));

    sd_card_t *sd = sd_get_by_num(0);
    if (!sd) return -1;

    FRESULT rc = f_mount(&sd->fatfs, "0:", 1);  /* 1 = mount immediately */
    return (rc == FR_OK) ? 0 : -1;
}
