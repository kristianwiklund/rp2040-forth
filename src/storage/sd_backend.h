#ifndef SD_BACKEND_H
#define SD_BACKEND_H

#include "vfs.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Initialise the SD card and mount the FAT filesystem on drive "0:".
   Must be called before vfs_register("/sd", &sd_ops).
   Returns 0 on success, non-zero on error. */
int sd_backend_init(void);

/* VFS operations table for the SD/FatFs backend.
   Register with: vfs_register("/sd", &sd_ops); */
extern const vfs_ops_t sd_ops;

#ifdef __cplusplus
}
#endif

#endif /* SD_BACKEND_H */
