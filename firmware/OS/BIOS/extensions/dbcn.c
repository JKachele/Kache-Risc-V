/*************************************************
 *File----------dbcn.c
 *Project-------Kache-Risc-V
 *Author--------Justin Kachele
 *Created-------Wednesday Apr 22, 2026 19:16:24 UTC
 *License-------GNU GPL-3.0
 ************************************************/

#include "dbcn.h"

extern void _putchar(char c);

static struct sbiret sbi_debug_console_write(u32 num_bytes, char *base_addr_lo, char *base_addr_hi) {
        for (int i = 0; i < num_bytes; i++) {
                _putchar(base_addr_lo[i]);
        }
        return (struct sbiret){.error = SBI_SUCCESS, .uvalue = num_bytes};
}

// EID #0x4442434E
struct sbiret dbcn(long arg0, long arg1, long arg2, long arg3, long arg4,
                       long arg5, long fid) {
        struct sbiret ret = {0};
        switch (fid) {
                case 0x0:
                        ret = sbi_debug_console_write(arg0, (char *)arg1, (char *)arg2);
                        break;
                case 0x2:
                        _putchar(arg0);
                        ret.error = SBI_SUCCESS;
                default:
                        ret.error = SBI_ERR_NOT_SUPPORTED;
        }
        return ret;
}


