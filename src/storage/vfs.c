#include "vfs.h"
#include <string.h>
#include <stdint.h>

/* ---- Internal state ---------------------------------------------------- */

typedef struct {
    const char     *prefix;
    const vfs_ops_t *ops;
} mount_t;

typedef struct {
    uint8_t mount_idx;   /* 1-based index into mounts[]; 0 = free slot */
    int     backend_fd;
} fd_entry_t;

static mount_t   mounts[VFS_MAX_MOUNTS];
static fd_entry_t fd_table[VFS_MAX_FILES];
static int       num_mounts;

/* ---- Public API --------------------------------------------------------- */

void vfs_init(void) {
    memset(mounts,   0, sizeof(mounts));
    memset(fd_table, 0, sizeof(fd_table));
    num_mounts = 0;
}

void vfs_register(const char *prefix, const vfs_ops_t *ops) {
    if (num_mounts >= VFS_MAX_MOUNTS) return;
    mounts[num_mounts].prefix = prefix;
    mounts[num_mounts].ops    = ops;
    num_mounts++;
}

/* Find the best-matching mount for path; store backend-relative suffix. */
static int find_mount(const char *path, const char **suffix) {
    int best     = -1;
    int best_len = 0;
    for (int i = 0; i < num_mounts; i++) {
        int plen = (int)strlen(mounts[i].prefix);
        if (strncmp(path, mounts[i].prefix, (size_t)plen) == 0
                && plen > best_len) {
            best     = i;
            best_len = plen;
        }
    }
    if (best >= 0) {
        *suffix = path + best_len;
        if (**suffix == '/') (*suffix)++;   /* skip leading slash in suffix */
    }
    return best;
}

int vfs_open(const char *path, int flags) {
    const char *suffix = NULL;
    int mi = find_mount(path, &suffix);
    if (mi < 0 || !mounts[mi].ops || !mounts[mi].ops->open) return 0;

    /* Find a free slot in the global fd table. */
    for (int i = 0; i < VFS_MAX_FILES; i++) {
        if (fd_table[i].mount_idx == 0) {
            int bfd = mounts[mi].ops->open(suffix, flags);
            if (bfd < 0) return 0;
            fd_table[i].mount_idx  = (uint8_t)(mi + 1);
            fd_table[i].backend_fd = bfd;
            return i + 1;   /* 1-based global fd */
        }
    }
    return 0;   /* fd table full */
}

void vfs_close(int fd) {
    if (fd < 1 || fd > VFS_MAX_FILES) return;
    fd_entry_t *e = &fd_table[fd - 1];
    if (e->mount_idx == 0) return;
    int mi = e->mount_idx - 1;
    if (mounts[mi].ops && mounts[mi].ops->close)
        mounts[mi].ops->close(e->backend_fd);
    e->mount_idx  = 0;
    e->backend_fd = 0;
}

int vfs_read(int fd, void *buf, int len) {
    if (fd < 1 || fd > VFS_MAX_FILES) return -1;
    fd_entry_t *e = &fd_table[fd - 1];
    if (e->mount_idx == 0) return -1;
    int mi = e->mount_idx - 1;
    if (!mounts[mi].ops || !mounts[mi].ops->read) return -1;
    return mounts[mi].ops->read(e->backend_fd, buf, len);
}

int vfs_write(int fd, const void *buf, int len) {
    if (fd < 1 || fd > VFS_MAX_FILES) return -1;
    fd_entry_t *e = &fd_table[fd - 1];
    if (e->mount_idx == 0) return -1;
    int mi = e->mount_idx - 1;
    if (!mounts[mi].ops || !mounts[mi].ops->write) return -1;
    return mounts[mi].ops->write(e->backend_fd, buf, len);
}

int vfs_seek(int fd, int offset, int whence) {
    if (fd < 1 || fd > VFS_MAX_FILES) return -1;
    fd_entry_t *e = &fd_table[fd - 1];
    if (e->mount_idx == 0) return -1;
    int mi = e->mount_idx - 1;
    if (!mounts[mi].ops || !mounts[mi].ops->seek) return -1;
    return mounts[mi].ops->seek(e->backend_fd, offset, whence);
}

int vfs_size(int fd) {
    if (fd < 1 || fd > VFS_MAX_FILES) return -1;
    fd_entry_t *e = &fd_table[fd - 1];
    if (e->mount_idx == 0) return -1;
    int mi = e->mount_idx - 1;
    if (!mounts[mi].ops || !mounts[mi].ops->size) return -1;
    return mounts[mi].ops->size(e->backend_fd);
}

int vfs_unlink(const char *path) {
    const char *suffix = NULL;
    int mi = find_mount(path, &suffix);
    if (mi < 0 || !mounts[mi].ops || !mounts[mi].ops->unlink) return -1;
    return mounts[mi].ops->unlink(suffix);
}
