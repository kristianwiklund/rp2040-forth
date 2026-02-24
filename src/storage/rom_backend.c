/*
 * ROM backend for the VFS layer.
 *
 * Exposes named rodata blobs as read-only VFS files under /rom/.
 *
 * Currently provides:
 *   /rom/boot.fth  — the forthdefs bootstrap source (compiled into flash
 *                    via .ascii/.asciz in forth.S).
 *
 * forthdefs and forthdefs_end are exported from forth.S so that the size
 * can be calculated as (forthdefs_end - forthdefs).
 */

#include "rom_backend.h"
#include <string.h>

/* Declared in forth.S / the linker map. */
extern const char forthdefs[];
extern const char forthdefs_end[];

/* ---- ROM table --------------------------------------------------------- */

typedef struct {
    const char *name;
    const char *data;
    int         len;
} rom_entry_t;

static const rom_entry_t rom_table[] = {
    { "boot.fth", forthdefs, 0 },   /* len filled in at init */
    { NULL, NULL, 0 }
};

/* Mutable copy of table so we can fill in the length at init time. */
static rom_entry_t entries[sizeof(rom_table) / sizeof(rom_table[0])];

/* ---- File handle ------------------------------------------------------- */

typedef struct {
    int entry_idx;
    int pos;
    int in_use;
} rom_handle_t;

static rom_handle_t handles[VFS_MAX_FILES];

/* ---- Backend operations ------------------------------------------------ */

static int rom_open(const char *path, int flags) {
    if (flags & (VFS_O_WRITE | VFS_O_CREAT | VFS_O_TRUNC)) return -1;

    for (int i = 0; entries[i].name; i++) {
        if (strcmp(entries[i].name, path) == 0) {
            for (int j = 0; j < VFS_MAX_FILES; j++) {
                if (!handles[j].in_use) {
                    handles[j].entry_idx = i;
                    handles[j].pos       = 0;
                    handles[j].in_use    = 1;
                    return j;
                }
            }
            return -1;  /* no free handle */
        }
    }
    return -1;  /* not found */
}

static void rom_close(int fd) {
    if (fd >= 0 && fd < VFS_MAX_FILES)
        handles[fd].in_use = 0;
}

static int rom_read(int fd, void *buf, int len) {
    if (fd < 0 || fd >= VFS_MAX_FILES || !handles[fd].in_use) return -1;
    rom_handle_t      *h = &handles[fd];
    const rom_entry_t *e = &entries[h->entry_idx];
    int remaining = e->len - h->pos;
    if (remaining <= 0) return 0;   /* EOF */
    int n = len < remaining ? len : remaining;
    memcpy(buf, e->data + h->pos, (size_t)n);
    h->pos += n;
    return n;
}

static int rom_seek(int fd, int offset, int whence) {
    if (fd < 0 || fd >= VFS_MAX_FILES || !handles[fd].in_use) return -1;
    rom_handle_t      *h = &handles[fd];
    const rom_entry_t *e = &entries[h->entry_idx];
    int newpos;
    switch (whence) {
        case 0: newpos = offset; break;
        case 1: newpos = h->pos + offset; break;
        case 2: newpos = e->len + offset; break;
        default: return -1;
    }
    if (newpos < 0) newpos = 0;
    h->pos = newpos;
    return 0;
}

static int rom_size(int fd) {
    if (fd < 0 || fd >= VFS_MAX_FILES || !handles[fd].in_use) return -1;
    return entries[handles[fd].entry_idx].len;
}

const vfs_ops_t rom_ops = {
    .open   = rom_open,
    .close  = rom_close,
    .read   = rom_read,
    .write  = NULL,
    .seek   = rom_seek,
    .size   = rom_size,
    .unlink = NULL,
};

/* ---- Init -------------------------------------------------------------- */

void rom_backend_init(void) {
    memset(handles, 0, sizeof(handles));

    /* Copy the static table and fill in the calculated length for boot.fth. */
    int i = 0;
    for (; rom_table[i].name; i++) {
        entries[i] = rom_table[i];
        if (entries[i].len == 0 && entries[i].data)
            entries[i].len = (int)(forthdefs_end - forthdefs);
    }
    entries[i].name = NULL;
    entries[i].data = NULL;
    entries[i].len  = 0;
}
