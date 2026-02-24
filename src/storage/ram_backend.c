/*
 * RAM filesystem backend for the VFS layer.
 *
 * Stores up to RAM_MAX_FILES named text blobs in a static SRAM pool.
 * The pool is separate from the Forth heap to avoid interfering with
 * dictionary allocation.
 *
 * Typical use: load a Forth source string via ram_create(), then
 * INCLUDE /ram/foo.fth  — useful for testing without SD hardware.
 */

#include "ram_backend.h"
#include <string.h>

/* ---- SRAM pool --------------------------------------------------------- */

static char pool[RAM_POOL_SIZE];
static int  pool_used;   /* bytes allocated so far */

typedef struct {
    char name[RAM_NAME_MAX];
    char *data;
    int   len;
} ram_slot_t;

static ram_slot_t slots[RAM_MAX_FILES];

/* ---- File handle ------------------------------------------------------- */

/* Each open handle tracks the slot index and current read position. */
typedef struct {
    int slot_idx;
    int pos;
    int in_use;
} ram_handle_t;

static ram_handle_t handles[VFS_MAX_FILES];

/* ---- Backend operations ------------------------------------------------ */

static int ram_open(const char *path, int flags) {
    /* Find the named slot. */
    int si = -1;
    for (int i = 0; i < RAM_MAX_FILES; i++) {
        if (slots[i].data && strncmp(slots[i].name, path, RAM_NAME_MAX) == 0) {
            si = i;
            break;
        }
    }
    if (si < 0) return -1;   /* not found */

    /* Only read is supported (RAM slots are written via ram_create). */
    if (flags & (VFS_O_WRITE | VFS_O_CREAT | VFS_O_TRUNC)) return -1;

    /* Find a free handle. */
    for (int i = 0; i < VFS_MAX_FILES; i++) {
        if (!handles[i].in_use) {
            handles[i].slot_idx = si;
            handles[i].pos      = 0;
            handles[i].in_use   = 1;
            return i;
        }
    }
    return -1;  /* no free handle */
}

static void ram_close(int fd) {
    if (fd >= 0 && fd < VFS_MAX_FILES)
        handles[fd].in_use = 0;
}

static int ram_read(int fd, void *buf, int len) {
    if (fd < 0 || fd >= VFS_MAX_FILES || !handles[fd].in_use) return -1;
    ram_handle_t *h = &handles[fd];
    ram_slot_t   *s = &slots[h->slot_idx];
    int remaining = s->len - h->pos;
    if (remaining <= 0) return 0;   /* EOF */
    int n = len < remaining ? len : remaining;
    memcpy(buf, s->data + h->pos, (size_t)n);
    h->pos += n;
    return n;
}

static int ram_seek(int fd, int offset, int whence) {
    if (fd < 0 || fd >= VFS_MAX_FILES || !handles[fd].in_use) return -1;
    ram_handle_t *h = &handles[fd];
    int newpos;
    switch (whence) {
        case 0: newpos = offset; break;
        case 1: newpos = h->pos + offset; break;
        case 2: newpos = slots[h->slot_idx].len + offset; break;
        default: return -1;
    }
    if (newpos < 0) newpos = 0;
    h->pos = newpos;
    return 0;
}

static int ram_size(int fd) {
    if (fd < 0 || fd >= VFS_MAX_FILES || !handles[fd].in_use) return -1;
    return slots[handles[fd].slot_idx].len;
}

const vfs_ops_t ram_ops = {
    .open   = ram_open,
    .close  = ram_close,
    .read   = ram_read,
    .write  = NULL,    /* RAM slots are written via ram_create(), not vfs_write() */
    .seek   = ram_seek,
    .size   = ram_size,
    .unlink = NULL,
};

/* ---- Public API -------------------------------------------------------- */

void ram_backend_init(void) {
    memset(pool,    0, sizeof(pool));
    memset(slots,   0, sizeof(slots));
    memset(handles, 0, sizeof(handles));
    pool_used = 0;
}

int ram_create(const char *name, const char *data, int len) {
    if (!name || !data || len <= 0) return -1;
    if (strnlen(name, RAM_NAME_MAX) >= RAM_NAME_MAX) return -1;

    /* Check if slot with this name already exists (overwrite). */
    for (int i = 0; i < RAM_MAX_FILES; i++) {
        if (slots[i].data && strncmp(slots[i].name, name, RAM_NAME_MAX) == 0) {
            if (len > slots[i].len) return -1;  /* can't grow in place */
            memcpy(slots[i].data, data, (size_t)len);
            slots[i].len = len;
            return 0;
        }
    }

    /* Find a free slot. */
    for (int i = 0; i < RAM_MAX_FILES; i++) {
        if (!slots[i].data) {
            if (pool_used + len > RAM_POOL_SIZE) return -1;  /* pool full */
            slots[i].data = pool + pool_used;
            slots[i].len  = len;
            pool_used    += len;
            strncpy(slots[i].name, name, RAM_NAME_MAX - 1);
            memcpy(slots[i].data, data, (size_t)len);
            return 0;
        }
    }
    return -1;  /* no free slot */
}
