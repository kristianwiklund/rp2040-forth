#ifndef RAM_BACKEND_H
#define RAM_BACKEND_H

#include "vfs.h"

#ifdef __cplusplus
extern "C" {
#endif

#define RAM_MAX_FILES    4
#define RAM_NAME_MAX    16
#define RAM_POOL_SIZE 2048   /* bytes of SRAM reserved for RAM filesystem */

/* Initialise the RAM backend (zero all slots). */
void ram_backend_init(void);

/* Create or overwrite a named RAM slot.
   Returns 0 on success, -1 if name is too long or pool is full. */
int ram_create(const char *name, const char *data, int len);

/* VFS operations table for the RAM backend.
   Register with: vfs_register("/ram", &ram_ops); */
extern const vfs_ops_t ram_ops;

#ifdef __cplusplus
}
#endif

#endif /* RAM_BACKEND_H */
