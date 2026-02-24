#ifndef VFS_H
#define VFS_H

#ifdef __cplusplus
extern "C" {
#endif

#define VFS_MAX_MOUNTS  4
#define VFS_MAX_FILES   8

#define VFS_O_READ      0x01
#define VFS_O_WRITE     0x02
#define VFS_O_CREAT     0x04
#define VFS_O_TRUNC     0x08

/* Backend operations table.  All function pointers are optional (NULL = not
   supported); the VFS layer checks before dispatching. */
typedef struct {
    /* Open a file at backend-relative path with flags; returns backend-local
       fd >= 0 on success, -1 on error. */
    int  (*open)  (const char *path, int flags);

    /* Close a backend fd. */
    void (*close) (int fd);

    /* Read up to len bytes into buf; returns bytes read, 0 on EOF, -1 on error. */
    int  (*read)  (int fd, void *buf, int len);

    /* Write len bytes from buf; returns bytes written, -1 on error. */
    int  (*write) (int fd, const void *buf, int len);

    /* Seek; whence: 0=SET 1=CUR 2=END.  Returns 0 on success, -1 on error. */
    int  (*seek)  (int fd, int offset, int whence);

    /* Return total file size in bytes, -1 on error. */
    int  (*size)  (int fd);

    /* Delete a file at backend-relative path.  Returns 0 on success, -1 on error. */
    int  (*unlink)(const char *path);
} vfs_ops_t;

/* Initialise the VFS (clear mount table and fd table). */
void vfs_init    (void);

/* Register a mount point.  prefix must match the start of the path exactly,
   e.g. "/sd".  Longest-prefix-wins when multiple mounts could match. */
void vfs_register(const char *prefix, const vfs_ops_t *ops);

/* Open a file by absolute path (e.g. "/sd/hello.fth").
   Returns a 1-based global fd on success, 0 on error. */
int  vfs_open    (const char *path, int flags);

void vfs_close   (int fd);
int  vfs_read    (int fd, void *buf, int len);
int  vfs_write   (int fd, const void *buf, int len);
int  vfs_seek    (int fd, int offset, int whence);
int  vfs_size    (int fd);
int  vfs_unlink  (const char *path);

#ifdef __cplusplus
}
#endif

#endif /* VFS_H */
