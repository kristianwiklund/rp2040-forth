#ifndef LFS_BACKEND_H
#define LFS_BACKEND_H

/*
 * LittleFS backend stub.
 *
 * LittleFS provides wear-levelled storage on the RP2040's internal flash.
 * This header reserves the slot; lfs_backend.c does not exist yet.
 *
 * To activate:
 *   1. Add LittleFS library to platformio.ini.
 *   2. Implement lfs_backend.c with lfs_ops pointing to real lfs_open/read/etc.
 *   3. In main.cpp: lfs_backend_init(); vfs_register("/lfs", &lfs_ops);
 */

#include "vfs.h"

#ifdef __cplusplus
extern "C" {
#endif

/* All-NULL ops table — registering this mount will cause every open to fail
   gracefully (vfs_open returns 0) until the real implementation is added. */
static const vfs_ops_t lfs_ops = {
    .open   = NULL,
    .close  = NULL,
    .read   = NULL,
    .write  = NULL,
    .seek   = NULL,
    .size   = NULL,
    .unlink = NULL,
};

#ifdef __cplusplus
}
#endif

#endif /* LFS_BACKEND_H */
