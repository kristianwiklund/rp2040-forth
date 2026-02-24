#ifndef ROM_BACKEND_H
#define ROM_BACKEND_H

#include "vfs.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Initialise the ROM backend (no-op for built-in blobs, but call for clarity). */
void rom_backend_init(void);

/* VFS operations table for the ROM backend.
   Register with: vfs_register("/rom", &rom_ops);
   Exposes: /rom/boot.fth  — the forthdefs bootstrap source. */
extern const vfs_ops_t rom_ops;

#ifdef __cplusplus
}
#endif

#endif /* ROM_BACKEND_H */
