/*************************************************
 *File----------srst.c
 *Project-------Kache-Risc-V
 *Author--------Justin Kachele
 *Created-------Wednesday Apr 22, 2026 19:16:20 UTC
 *License-------GNU GPL-3.0
 ************************************************/

#include "srst.h"

// EID #0x53525354
struct sbiret srst(long arg0, long arg1, long arg2, long arg3, long arg4,
                       long arg5, long fid) {
        struct sbiret ret = {0};
        switch (fid) {
                case 0x0:
                        asm volatile ("ebreak\n");
                        break;
                default:
                        ret.error = SBI_ERR_NOT_SUPPORTED;
        }
        return ret;
}


